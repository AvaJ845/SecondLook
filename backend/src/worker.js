/**
 * SecondLook AI gateway — Cloudflare Worker.
 *
 * Separate deployment from Pitchwire, same backend logic. The app talks ONLY to
 * this Worker; provider keys live in Worker secrets, never in the app.
 *
 *   POST /v1/generate
 *   Authorization: Bearer <SECONDLOOK_CLIENT_TOKEN>
 *   { "task", "tier", "input": {..}, "prompt" }
 *   -> 200 { "text", "model", "cached", "usage": { "inputTokens", "outputTokens" } }
 *
 * What the app sends: which SecondLook rules fired and the hiring stage. The
 * user's message text, screenshots, emails, names, and domains are NEVER sent —
 * the app strips them before the request is built (see AIAdvisor.swift). The
 * guardrails below assume that and never ask the model to judge a real entity.
 *
 * Failover chain per task, all free:  OpenRouter :free  ->  NVIDIA NIM.
 */

const NV_120      = "nvidia:openai/gpt-oss-120b";
const NV_20       = "nvidia:openai/gpt-oss-20b";
const OR_GLM      = "openrouter:z-ai/glm-5.2:free";
const OR_MINIMAX  = "openrouter:minimax/minimax-m2.7:free";
const OR_MINIMAX3 = "openrouter:minimax/minimax-m3:free";
const GLM_DIRECT  = ["glm-4.7-flash", "glm-4.5-flash"]; // Aliyun-blocked from CF; kept for a non-CF host

// Paid backstop appended to every chain when PAID_FALLBACK_ENABLED is set.
const OR_PAID     = "openrouter:z-ai/glm-4.6";

const TASK_MODELS = {
  // fast tier — short, grounded text
  plainSummary:   [OR_MINIMAX3, NV_20, OR_GLM, NV_120, ...GLM_DIRECT],
  verifyEmployer: [OR_MINIMAX3, NV_20, OR_GLM, NV_120, ...GLM_DIRECT],
  // quality tier — the reply a person will actually send
  replyCoach:     [OR_MINIMAX, NV_120, OR_GLM, OR_MINIMAX3, NV_20, ...GLM_DIRECT],
};

const MAX_TOKENS = {
  plainSummary:   320,
  verifyEmployer: 320,
  replyCoach:     400,
};

const MODEL_TIMEOUT_MS = 13_000;

// The hard guardrails. The app already guarantees no real entity names reach
// here, but the prompts still forbid the model from inventing or accusing one.
const GUARDRAILS =
  " Never state or imply that a specific named company, recruiter, or person is a scammer, " +
  "fraudulent, or fake — you are describing an automated pattern check, not making an accusation. " +
  "Use only the signals provided; do not invent new ones. Plain text only: no markdown, no headings, no bullet characters unless asked.";

const SYSTEM = {
  plainSummary:
    "You explain the result of an automated job-scam pattern check to a job seeker. " +
    "Given the hiring stage and the list of signals that matched, write 2 to 3 calm, plain sentences " +
    "about what stands out and what the person should be careful about. Do not repeat the signal list " +
    "verbatim — synthesize it." + GUARDRAILS,
  replyCoach:
    "You help a job seeker write a short, polite reply to a recruiter when an automated check flagged " +
    "concerning requests. Write 3 to 4 sentences the person can send that: decline to share money, " +
    "documents, or personal numbers for now; and ask to verify the role on a video call from a company " +
    "email address. Courteous, not accusatory. No greeting or sign-off line needed." + GUARDRAILS,
  verifyEmployer:
    "You help a job seeker verify an employer themselves. Output exactly two labelled blocks in plain text:\n" +
    "CHECKS:\n- three concrete things to confirm (job listing on the company's real site, recruiter on the " +
    "company's staff/LinkedIn page, email domain matches the official domain)\n" +
    "SEARCHES:\n- three specific web searches that would surface the truth\n" +
    "Keep each line short. You have no web access and must not invent company names, URLs, or facts." + GUARDRAILS,
};

export default {
  async fetch(request, env, ctx) {
    if (request.method !== "POST") return json({ error: "POST only" }, 405);
    const url = new URL(request.url);

    const auth = request.headers.get("Authorization") || "";
    if (auth !== `Bearer ${env.SECONDLOOK_CLIENT_TOKEN}`) {
      return json({ error: "unauthorized" }, 401);
    }

    const ip = request.headers.get("CF-Connecting-IP") || "anon";
    if (await rateLimited(ip, env)) return json({ error: "rate limited" }, 429);

    if (url.pathname !== "/v1/generate") return json({ error: "not found" }, 404);

    let body;
    try { body = await request.json(); } catch { return json({ error: "bad json" }, 400); }
    const { task, tier, input = {}, prompt = "" } = body;
    if (!TASK_MODELS[task]) return json({ error: `unknown task ${task}` }, 400);

    const only = url.searchParams.get("only");
    const paidFallback = env.PAID_FALLBACK_ENABLED === "1" || env.PAID_FALLBACK_ENABLED === "true";
    const chain = only
      ? [only]
      : (paidFallback ? [...TASK_MODELS[task], OR_PAID] : TASK_MODELS[task]);

    const cacheKey = await hash(JSON.stringify({ task, tier, input, prompt }));
    const cache = caches.default;
    const cachedURL = new URL(request.url);
    cachedURL.pathname = `/cache/${cacheKey}`;
    if (!only) {
      const hit = await cache.match(cachedURL);
      if (hit) {
        const data = await hit.json();
        return json({ ...data, cached: true });
      }
    }

    const messages = [
      { role: "system", content: SYSTEM[task] },
      { role: "user", content: buildUserContent(prompt, input) },
    ];
    const temperature = tier === "quality" ? 0.6 : 0.2;
    const maxTokens = MAX_TOKENS[task] || 400;

    const errs = [];
    for (const model of chain) {
      try {
        const out = await callModel(model, messages, temperature, maxTokens, env);
        const payload = { text: out.text, model: out.model, cached: false, usage: out.usage };
        if (!only) ctx.waitUntil(cache.put(cachedURL, json(payload, 200, 60 * 60 * 6)));
        return json(payload);
      } catch (e) {
        const line = `${model}: ${e.message || e}`;
        errs.push(line);
        console.log("provider failed:", line);
        if (e.status === 401 || e.status === 403) break;
      }
    }
    return json({ error: "all providers failed", detail: errs }, 502);
  },
};

async function callModel(model, messages, temperature, maxTokens, env) {
  let baseURL, apiKey, realModel;
  const extraHeaders = {};
  if (model.startsWith("nvidia:")) {
    baseURL = "https://integrate.api.nvidia.com/v1";
    apiKey = env.NVIDIA_API_KEY;
    realModel = model.slice("nvidia:".length);
  } else if (model.startsWith("openrouter:")) {
    baseURL = "https://openrouter.ai/api/v1";
    apiKey = env.OPENROUTER_API_KEY;
    realModel = model.slice("openrouter:".length);
    extraHeaders["HTTP-Referer"] = "https://github.com/AvaJ845/SecondLook";
    extraHeaders["X-Title"] = "SecondLook";
  } else {
    baseURL = "https://api.z.ai/api/paas/v4";
    apiKey = env.ZAI_API_KEY;
    realModel = model;
  }
  if (!apiKey) { const err = new Error(`no key for ${model}`); err.status = 500; throw err; }

  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), MODEL_TIMEOUT_MS);
  let res;
  try {
    res = await fetch(`${baseURL}/chat/completions`, {
      method: "POST",
      signal: ctrl.signal,
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        "Accept": "application/json",
        "User-Agent": "SecondLook/1.0 (+https://github.com/AvaJ845/SecondLook)",
        ...extraHeaders,
      },
      body: JSON.stringify({ model: realModel, messages, temperature, stream: false, max_tokens: maxTokens }),
    });
  } catch (e) {
    const err = new Error(e.name === "AbortError" ? `timeout after ${MODEL_TIMEOUT_MS}ms` : String(e));
    err.status = 504;
    throw err;
  } finally {
    clearTimeout(timer);
  }
  if (!res.ok) {
    const text = (await res.text().catch(() => "")).slice(0, 300);
    const err = new Error(`HTTP ${res.status} ${text}`);
    err.status = res.status;
    throw err;
  }
  const data = await res.json();
  const text = data?.choices?.[0]?.message?.content;
  if (!text) { const err = new Error("empty completion"); err.status = 502; throw err; }
  return {
    text: text.trim(),
    model: data.model || realModel,
    usage: data.usage
      ? { inputTokens: data.usage.prompt_tokens ?? 0, outputTokens: data.usage.completion_tokens ?? 0 }
      : null,
  };
}

function buildUserContent(prompt, input) {
  const facts = Object.entries(input).map(([k, v]) => `${k}: ${v}`).join("\n");
  return facts ? `${prompt}\n\n${facts}` : prompt;
}

async function rateLimited(ip, env) {
  const limit = Number(env.RATE_LIMIT_PER_MIN || 20);
  const cache = caches.default;
  const key = new URL(`https://rl.secondlook/${ip}/${Math.floor(Date.now() / 60000)}`);
  const cur = await cache.match(key);
  const count = cur ? Number(await cur.text()) : 0;
  if (count >= limit) return true;
  await cache.put(key, new Response(String(count + 1), { headers: { "Cache-Control": "max-age=70" } }));
  return false;
}

async function hash(s) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function json(obj, status = 200, maxAge = 0) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...(maxAge ? { "Cache-Control": `max-age=${maxAge}` } : {}),
    },
  });
}
