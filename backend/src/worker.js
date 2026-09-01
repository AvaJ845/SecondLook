/**
 * SecondLook AI gateway — Cloudflare Worker.
 *
 * Separate deployment from Pitchwire (`secondlook-ai` vs `pitchwire-ai`), same
 * backend logic. The app talks ONLY to this Worker; provider keys live in Worker
 * secrets, never in the app.
 *
 *   POST /v1/generate
 *   Authorization: Bearer <SECONDLOOK_CLIENT_TOKEN>
 *   { "task", "tier", "input": {..}, "prompt" }
 *   -> 200 { "text", "model", "cached", "usage": { "inputTokens", "outputTokens" } }
 *
 * Two privacy tiers:
 *
 *  - plainSummary / replyCoach / verifyEmployer  (text tasks)
 *      input = the app's own rule metadata only (which signals fired, the hiring
 *      stage). No user message text, no image. Used for the always-on report.
 *
 *  - deepCheck  (multimodal, opt-in in the app)
 *      input.text  = the pasted / OCR'd message
 *      input.image = a data: URL (base64 JPEG/PNG) of the screenshot
 *      Sent ONLY when the user taps "Deep AI check" and has accepted the
 *      one-time consent. Uses a vision model to read the screenshot directly.
 *
 * The system prompts forbid the model from naming or accusing any real company
 * or person in every task.
 */

// ─── text-task models (free) ──────────────────────────────────────────────────
const NV_120      = "nvidia:openai/gpt-oss-120b";
const NV_20       = "nvidia:openai/gpt-oss-20b";
const OR_GLM      = "openrouter:z-ai/glm-5.2:free";
const OR_MINIMAX  = "openrouter:minimax/minimax-m2.7:free";
const OR_MINIMAX3 = "openrouter:minimax/minimax-m3:free";
const GLM_DIRECT  = ["glm-4.7-flash", "glm-4.5-flash"]; // Aliyun-blocked from CF; kept for a non-CF host
const OR_PAID     = "openrouter:z-ai/glm-4.6";          // paid backstop, tail only

// ─── vision models for deepCheck ──────────────────────────────────────────────
// OpenRouter, vision-capable. IDs drift — verify against
// https://openrouter.ai/models?modality=text+image->text (see README).
// NVIDIA's free tier is text-only (gpt-oss), so it can't sit in this chain;
// a text-only retry on the strongest text model is the final fallback instead.
const VISION_FREE = [
  "openrouter:meta-llama/llama-3.2-11b-vision-instruct:free",
  "openrouter:mistralai/mistral-small-3.2-24b-instruct:free",
  "openrouter:qwen/qwen-2.5-vl-7b-instruct:free",
  "openrouter:google/gemini-2.0-flash-exp:free",
];
const VISION_PAID = "openrouter:qwen/qwen-2.5-vl-72b-instruct"; // paid backstop
// Used when every vision model fails but we still have text to work with.
const VISION_TEXT_FALLBACK = [OR_MINIMAX, NV_120, OR_GLM];

const TASK_MODELS = {
  plainSummary:   [OR_MINIMAX3, NV_20, OR_GLM, NV_120, ...GLM_DIRECT],
  verifyEmployer: [OR_MINIMAX3, NV_20, OR_GLM, NV_120, ...GLM_DIRECT],
  replyCoach:     [OR_MINIMAX, NV_120, OR_GLM, OR_MINIMAX3, NV_20, ...GLM_DIRECT],
  deepCheck:      VISION_FREE, // + text fallback appended at request time
};

const MAX_TOKENS = {
  plainSummary:   320,
  verifyEmployer: 320,
  replyCoach:     400,
  deepCheck:      700,
};

const MODEL_TIMEOUT_MS = 20_000; // vision is slower; app's own timeout is 25s

const GUARDRAILS =
  " Never state or imply that a specific named company, recruiter, or person is a scammer, " +
  "fraudulent, or fake — you are describing patterns, not making an accusation about a real entity. " +
  "Plain text only: no markdown, no headings, no asterisks.";

const SYSTEM = {
  plainSummary:
    "You explain the result of an automated job-scam pattern check to a job seeker. " +
    "Given the hiring stage and the signals that matched, write 2 to 3 calm, plain sentences about " +
    "what stands out and what to be careful about. Synthesize, don't list." + GUARDRAILS,
  replyCoach:
    "You help a job seeker write a short, polite reply after an automated check flagged concerning " +
    "requests. 3 to 4 sentences they can send: decline to share money, documents, or personal numbers " +
    "for now; ask to verify the role on a video call from a company email address. No greeting or " +
    "sign-off needed." + GUARDRAILS,
  verifyEmployer:
    "You help a job seeker verify an employer themselves. Output exactly two labelled blocks in plain text:\n" +
    "CHECKS:\n- three concrete things to confirm (job on the company's real site, recruiter on its " +
    "staff/LinkedIn page, email domain matches the official one)\n" +
    "SEARCHES:\n- three specific web searches that would surface the truth\n" +
    "You have no web access; do not invent company names, URLs, or facts." + GUARDRAILS,
  deepCheck:
    "You are SecondLook, helping a job seeker decide whether a job message is safe to act on. " +
    "You are given the message as text and/or a screenshot, plus the person's hiring stage. " +
    "Read everything carefully and reason about whether the requests match a legitimate hiring process " +
    "at that stage. Pay attention to: requests for money, gift cards, wires, or crypto; requests for SSN, " +
    "bank details, or ID documents before a real offer; check-deposit / 'send money back' schemes; " +
    "interviews only over chat apps; offers with no live interview; lookalike or free-mail sender domains; " +
    "pressure and urgency; reshipping or payment-processing roles.\n" +
    "Output plain text in exactly these labelled blocks:\n" +
    "READ: one sentence — one of 'looks consistent with a real process', 'a few things worth checking', " +
    "or 'several things do not line up'.\n" +
    "CONCERNS:\n- each specific thing that stands out, one per line, with a short why. If none, write '- none found'.\n" +
    "REPLY: 2 to 3 sentences the person could send that protects them without accusing anyone.\n" +
    "VERIFY:\n- two or three concrete steps to confirm the employer independently.\n" +
    "Ground every concern in something actually present in the message or image." + GUARDRAILS,
};

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (url.pathname === "/health") return json({ ok: true, worker: "secondlook-ai" });

    if (request.method !== "POST") return json({ error: "POST only" }, 405);

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

    const isVision = task === "deepCheck" && typeof input.image === "string" && input.image.startsWith("data:");
    const only = url.searchParams.get("only");
    const paidFallback = env.PAID_FALLBACK_ENABLED === "1" || env.PAID_FALLBACK_ENABLED === "true";

    let chain;
    if (only) {
      chain = [only];
    } else if (task === "deepCheck") {
      chain = [...VISION_FREE];
      if (paidFallback) chain.push(VISION_PAID);
      chain.push(...VISION_TEXT_FALLBACK); // last resort: text-only on a strong model
    } else {
      chain = paidFallback ? [...TASK_MODELS[task], OR_PAID] : TASK_MODELS[task];
    }

    // Cache by content. The image is part of the key, so an identical screenshot
    // + text is only charged once. deepCheck cache is short (10 min).
    const cacheKey = await hash(JSON.stringify({ task, tier, input, prompt }));
    const cache = caches.default;
    const cachedURL = new URL(request.url);
    cachedURL.pathname = `/cache/${cacheKey}`;
    if (!only) {
      const hit = await cache.match(cachedURL);
      if (hit) return json({ ...(await hit.json()), cached: true });
    }

    const userContent = isVision
      ? [
          { type: "text", text: buildUserContent(prompt, { text: input.text, hiring_stage: input.hiring_stage }) },
          { type: "image_url", image_url: { url: input.image } },
        ]
      : buildUserContent(prompt, task === "deepCheck" ? { text: input.text, hiring_stage: input.hiring_stage } : input);

    const messages = [
      { role: "system", content: SYSTEM[task] },
      { role: "user", content: userContent },
    ];
    const temperature = tier === "quality" || task === "deepCheck" ? 0.4 : 0.2;
    const maxTokens = MAX_TOKENS[task] || 400;

    const errs = [];
    for (const model of chain) {
      // Once we've dropped to the text-only fallback list, strip the image.
      const textOnly = VISION_TEXT_FALLBACK.includes(model);
      const msgs = textOnly
        ? [{ role: "system", content: SYSTEM[task] },
           { role: "user", content: buildUserContent(prompt, { text: input.text, hiring_stage: input.hiring_stage }) }]
        : messages;
      try {
        const out = await callModel(model, msgs, temperature, maxTokens, env);
        const payload = { text: out.text, model: out.model, cached: false, usage: out.usage };
        const ttl = task === "deepCheck" ? 600 : 60 * 60 * 6;
        if (!only) ctx.waitUntil(cache.put(cachedURL, json(payload, 200, ttl)));
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
    text: (typeof text === "string" ? text : JSON.stringify(text)).trim(),
    model: data.model || realModel,
    usage: data.usage
      ? { inputTokens: data.usage.prompt_tokens ?? 0, outputTokens: data.usage.completion_tokens ?? 0 }
      : null,
  };
}

function buildUserContent(prompt, input) {
  const facts = Object.entries(input)
    .filter(([, v]) => v != null && String(v).length)
    .map(([k, v]) => `${k}: ${v}`)
    .join("\n");
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
