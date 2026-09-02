/**
 * SecondLook AI gateway — Cloudflare Worker.
 *
 * Separate deployment from Pitchwire (`secondlook-ai` vs `pitchwire-ai`), same
 * backend logic. The app talks ONLY to this Worker; provider keys live in Worker
 * secrets, never in the app.
 *
 * ── Abuse resistance (P0 #2) ──────────────────────────────────────────────────
 *   1. GET  /v1/register/challenge          -> { challenge }
 *   2. POST /v1/register                    Authorization: Bearer <BOOTSTRAP>
 *        { installId, deviceToken? }        -> { token, expiresAt }
 *        - deviceToken is Apple DeviceCheck output; verified with Apple when the
 *          DEVICECHECK_* secrets are configured, otherwise accepted on the
 *          bootstrap token alone (enforcement is a secret away, no app update).
 *        - `token` is a 24h HMAC (INSTALL_TOKEN_SECRET) bound to installId.
 *   3. POST /v1/generate                    Authorization: Bearer <install token
 *                                           OR bootstrap>
 *        - Every call passes through a per-identity Durable Object rate limiter
 *          (atomic, global — replaces the old per-PoP cache counter). Requests
 *          on a bare bootstrap token get a much tighter limit.
 *
 * No user account, ever. The install token carries no identity — just "this
 * install passed attestation." The standard on-device check never touches any
 * of this.
 *
 *   POST /v1/generate
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

// ─── models — no paid spend ───────────────────────────────────────────────────
// Two providers, both free for this account:
//   openrouter:  ":free" models only (no credit; ~50 req/day/account shared).
//            Lead here — this key can call more of them than NVIDIA's. A hard
//            skip in the call loop blocks any openrouter id without ":free".
//   nvidia:  NVIDIA NIM serverless. This key serves only a couple of ids (most
//            of the /v1/models catalog 404s), so it's a backup, not the lead.
//
// Model ids drift fast, and a model in the catalog is NOT proof the account can
// call it (NVIDIA lists ~80, this key serves a handful). Verified working
// 2026-09-01 by probing the deployed worker with `?only=<id>`:
//   nvidia:nvidia/nemotron-3.5-lightning-30b-a3b   200  ~6s   (reasoning preamble — stripped below)
//   openrouter:minimax/minimax-m2.7:free           200  ~4.5s clean
//   nvidia:moonshotai/kimi-k3                       HANGS 20s  ← was the deepCheck timeout; do NOT use
//   nvidia:zai-org/glm-5.3-flash                    404        ← never existed on NIM
// Refresh with: GET /v1/models  and  GET /v1/models?provider=nvidia
const NV_LIGHTNING = "nvidia:nvidia/nemotron-3.5-lightning-30b-a3b"; // verified 200
const OR_MINIMAX   = "openrouter:minimax/minimax-m2.7:free";         // verified 200, clean
const OR_GLM       = "openrouter:z-ai/glm-5.2:free";                 // free_text list; sometimes 429
const OR_NEM_ULTRA = "openrouter:nvidia/nemotron-3-ultra-550b-a55b:free";

// Vision-capable, from the /v1/models free_vision list. NVIDIA vision models all
// returned "not found for account" on this key, so vision runs on OpenRouter
// free. The deepCheck chain is SHORT on purpose: the app waits ~60s total, so we
// can only afford a primary + one vision fallback + one text-only last resort
// within the budget (see REQUEST_BUDGET_MS).
const VISION_MODELS = [
  "openrouter:minimax/minimax-m3:free",
  "openrouter:google/gemma-4-31b-it:free",
  "openrouter:google/gemma-4-26b-a4b-it:free",
  "openrouter:nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free",
];
// Actually attempted for a deepCheck request, in order.
const DEEPCHECK_VISION = ["openrouter:minimax/minimax-m3:free", "openrouter:google/gemma-4-31b-it:free"];
const VISION_TEXT_FALLBACK = [OR_MINIMAX]; // image stripped, last resort only

const TASK_MODELS = {
  plainSummary:   [OR_MINIMAX, NV_LIGHTNING, OR_GLM],
  verifyEmployer: [OR_MINIMAX, NV_LIGHTNING, OR_GLM],
  replyCoach:     [OR_MINIMAX, NV_LIGHTNING, OR_GLM, OR_NEM_ULTRA],
  deepCheck:      VISION_MODELS, // presence gates the task; real chain built per request
};

const MAX_TOKENS = {
  plainSummary:   320,
  verifyEmployer: 320,
  replyCoach:     400,
  deepCheck:      700,
};

// Per-attempt ceiling. Also capped by whatever's left of REQUEST_BUDGET_MS, so
// a slow first model can't starve the fallback.
const MODEL_TIMEOUT_MS = 18_000;
// Total wall-clock for the whole fallback chain. Must stay comfortably under
// the app's deepCheck timeout (60s) minus the client<->worker round trip and
// JSON handling, so the worker always answers before the app gives up.
const REQUEST_BUDGET_MS = 50_000;
// Don't start another model attempt with less than this left on the budget.
const MIN_ATTEMPT_MS = 7_000;

/// Given the total budget and how long the chain has already run, decide
/// whether to start another model attempt and with what per-attempt timeout.
/// Pure — unit-tested in test/budget.test.mjs.
export function planAttempt(budgetMs, elapsedMs, perModelMs = MODEL_TIMEOUT_MS, minMs = MIN_ATTEMPT_MS) {
  const remaining = budgetMs - elapsedMs;
  if (remaining < minMs) return { go: false, timeoutMs: 0 };
  return { go: true, timeoutMs: Math.max(minMs, Math.min(perModelMs, remaining - 1_000)) };
}

// Per-isolate circuit breaker. A model that just timed out or 5xx'd is very
// likely to do it again on the next request — skip it for a few minutes rather
// than burn the whole time budget on it again (this is exactly what kimi-k3 did).
const BREAKER_COOLDOWN_MS = 4 * 60_000;
const breaker = new Map(); // model id -> epoch ms it may be retried
export function breakerOpen(model, now = Date.now()) {
  const until = breaker.get(model);
  return until != null && now < until;
}
export function breakerTrip(model, now = Date.now()) { breaker.set(model, now + BREAKER_COOLDOWN_MS); }
export function _breakerReset() { breaker.clear(); }

/// Some models (reasoning variants) prefix their answer with a visible
/// scratchpad. Strip `<think>…</think>` tags, and for our label-structured
/// tasks drop anything before the first real label so a preamble can't leak.
export function stripReasoning(text, task) {
  if (!text) return text;
  let t = text.replace(/<think>[\s\S]*?<\/think>/gi, "").trim();
  const firstLabel = { deepCheck: /^READ:/im, verifyEmployer: /^CHECKS:/im }[task];
  if (firstLabel) {
    const m = t.match(firstLabel);
    if (m && m.index > 0) t = t.slice(m.index).trim();
  }
  return t;
}

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

// Per-identity rate limits. deepCheck is the expensive multimodal path.
const LIMITS = {
  install: {
    deepCheck: { minLimit: 3, dayLimit: 25 },
    text: { minLimit: 15, dayLimit: 120 },
  },
  // A bare bootstrap token is the dev / first-run fallback — it should never
  // carry real volume.
  bootstrap: {
    deepCheck: { minLimit: 2, dayLimit: 8 },
    text: { minLimit: 6, dayLimit: 40 },
  },
};

export default {
  async fetch(request, env, ctx) {
    try {
      return await handle(request, env, ctx);
    } catch (e) {
      // A thrown exception would otherwise surface as an opaque Cloudflare 1101
      // that the app can't parse. Return clean JSON so it can fall back cleanly.
      console.log("unhandled:", e && (e.stack || e.message || String(e)));
      return json({ error: "internal error" }, 500);
    }
  },
};

async function handle(request, env, ctx) {
    const url = new URL(request.url);
    if (url.pathname === "/health") return json({ ok: true, worker: "secondlook-ai" });

    const bearer = (request.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
    const ip = request.headers.get("CF-Connecting-IP") || "anon";

    // ── Registration: bootstrap-authed, mints an install token ────────────────
    if (url.pathname === "/v1/register") {
      if (request.method !== "POST") return json({ error: "POST only" }, 405);
      if (!timingSafeEqual(bearer, env.SECONDLOOK_CLIENT_TOKEN || "")) {
        return json({ error: "unauthorized" }, 401);
      }
      // Cap install-token minting per IP so a leaked bootstrap token can't farm
      // fresh identities to sidestep the per-identity limit below.
      const reg = await checkRateLimit(env, `reg:${ip}`, { minLimit: 4, dayLimit: 20 });
      if (!reg.allowed) {
        return json({ error: "rate limited", scope: reg.scope }, 429, 0, { "Retry-After": String(reg.retryAfter || 60) });
      }
      return registerInstall(request, env, ip);
    }

    // ── Everything past here needs a token (install or bootstrap) ─────────────
    const identity = await resolveIdentity(bearer, env, ip);
    if (!identity) return json({ error: "unauthorized" }, 401);

    if (url.pathname === "/v1/models") {
      return url.searchParams.get("provider") === "nvidia"
        ? listNvidiaModels(env)
        : listFreeModels(env);
    }

    if (url.pathname !== "/v1/generate") return json({ error: "not found" }, 404);
    if (request.method !== "POST") return json({ error: "POST only" }, 405);

    // Body-size guard — the app caps deepCheck images at ~0.9 MB; anything much
    // bigger is abuse. 3 MB leaves generous headroom for base64 overhead.
    const contentLength = Number(request.headers.get("Content-Length") || 0);
    if (contentLength > 3_000_000) return json({ error: "payload too large" }, 413);

    let body;
    try { body = await request.json(); } catch { return json({ error: "bad json" }, 400); }
    const { task, tier, input = {}, prompt = "" } = body;
    if (!TASK_MODELS[task]) return json({ error: `unknown task ${task}` }, 400);

    // ── Atomic per-identity rate limit (Durable Object) ──────────────────────
    const bucket = task === "deepCheck" ? "deepCheck" : "text";
    const limits = LIMITS[identity.kind][bucket];
    const gate = await checkRateLimit(env, identity.key, limits);
    if (!gate.allowed) {
      return json(
        { error: "rate limited", scope: gate.scope, retryAfter: gate.retryAfter },
        429,
        0,
        { "Retry-After": String(gate.retryAfter || 60) }
      );
    }

    const isVision = task === "deepCheck" && typeof input.image === "string" && input.image.startsWith("data:");
    const only = url.searchParams.get("only");

    let chain;
    if (only) {
      chain = [only];
    } else if (task === "deepCheck") {
      // Short by design — see REQUEST_BUDGET_MS. With no image it's a plain
      // text call, so a couple of text models fit the budget fine.
      chain = isVision ? [...DEEPCHECK_VISION, ...VISION_TEXT_FALLBACK] : [OR_MINIMAX, NV_LIGHTNING];
    } else {
      chain = TASK_MODELS[task];
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
    const startedAt = Date.now();
    // Text tasks fail fast so the app's deterministic on-device result takes
    // over; deepCheck has no on-device equivalent and the user is waiting, so
    // it gets the full budget.
    const budget = task === "deepCheck" ? REQUEST_BUDGET_MS : 20_000;
    let ranOutOfTime = false;
    let lastWasTimeout = false;
    for (const model of chain) {
      // Safety net: never call a paid OpenRouter model, whatever the chain says.
      if (model.startsWith("openrouter:") && !model.endsWith(":free")) {
        errs.push(`${model}: skipped (not a :free model)`);
        continue;
      }
      // Circuit breaker — skip a model that just failed hard on this isolate,
      // unless it's the only thing left to try.
      if (breakerOpen(model) && !(only || model === chain[chain.length - 1])) {
        errs.push(`${model}: skipped (breaker open)`);
        continue;
      }
      // Budget guard — don't start an attempt we can't finish before the app
      // times out. Guarantees the worker answers first.
      const plan = planAttempt(budget, Date.now() - startedAt);
      if (!plan.go) {
        ranOutOfTime = true;
        errs.push(`${model}: skipped (out of time budget)`);
        break;
      }
      const attemptTimeout = plan.timeoutMs;
      // Once we've dropped to the text-only fallback list, strip the image.
      const textOnly = VISION_TEXT_FALLBACK.includes(model);
      const msgs = textOnly
        ? [{ role: "system", content: SYSTEM[task] },
           { role: "user", content: buildUserContent(prompt, { text: input.text, hiring_stage: input.hiring_stage }) }]
        : messages;
      try {
        const out = await callModel(model, msgs, temperature, maxTokens, env, attemptTimeout);
        const payload = { text: stripReasoning(out.text, task), model: out.model, cached: false, usage: out.usage };
        if (!payload.text) throw Object.assign(new Error("empty after cleanup"), { status: 502 });
        const ttl = task === "deepCheck" ? 600 : 60 * 60 * 6;
        if (!only) ctx.waitUntil(cache.put(cachedURL, json(payload, 200, ttl)));
        return json(payload);
      } catch (e) {
        const line = `${model}: ${e.message || e}`;
        errs.push(line);
        lastWasTimeout = e.status === 504;
        // Trip the breaker on a hang, a dead id, or a server-side failure —
        // not on a 429 (transient, will clear on its own).
        if (e.status === 504 || e.status === 404 || (e.status >= 500 && e.status !== 501)) breakerTrip(model);
        console.log("provider failed:", line);
        if (e.status === 401 || e.status === 403) break;
      }
    }
    // Don't echo upstream provider error text / model ids back to the client.
    if (only) return json({ error: "all providers failed", detail: errs }, 502);
    console.log("all providers failed:", errs.join(" | "));
    // 504 tells the app "took too long" (vs. a generic backend error) so it can
    // show the right message and the user knows a retry is worth it.
    const status = ranOutOfTime || lastWasTimeout ? 504 : 502;
    return json({ error: status === 504 ? "upstream timeout" : "all providers failed" }, status);
}

async function callModel(model, messages, temperature, maxTokens, env, timeoutMs = MODEL_TIMEOUT_MS) {
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
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
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
    const err = new Error(e.name === "AbortError" ? `timeout after ${timeoutMs}ms` : String(e));
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

async function listFreeModels(env) {
  if (!env.OPENROUTER_API_KEY) return json({ error: "OPENROUTER_API_KEY not set" }, 500);
  let data;
  try {
    const res = await fetch("https://openrouter.ai/api/v1/models", {
      headers: { "Authorization": `Bearer ${env.OPENROUTER_API_KEY}` },
    });
    data = await res.json();
  } catch (e) {
    return json({ error: String(e) }, 502);
  }
  const models = (data.data || [])
    .filter((m) => Number(m?.pricing?.prompt || 0) === 0 && Number(m?.pricing?.completion || 0) === 0)
    .map((m) => ({
      id: `openrouter:${m.id}`,
      vision: (m.architecture?.input_modalities || m.architecture?.modality || "").includes("image"),
      context: m.context_length,
    }));
  return json({
    free_text: models.filter((m) => !m.vision).map((m) => m.id),
    free_vision: models.filter((m) => m.vision).map((m) => m.id),
  });
}

async function listNvidiaModels(env) {
  if (!env.NVIDIA_API_KEY) return json({ error: "NVIDIA_API_KEY not set" }, 500);
  let data;
  try {
    const res = await fetch("https://integrate.api.nvidia.com/v1/models", {
      headers: { "Authorization": `Bearer ${env.NVIDIA_API_KEY}` },
    });
    data = await res.json();
  } catch (e) {
    return json({ error: String(e) }, 502);
  }
  const ids = (data.data || []).map((m) => `nvidia:${m.id}`).sort();
  return json({
    count: ids.length,
    // surface the two we want to wire, if present
    kimi: ids.filter((i) => i.toLowerCase().includes("kimi")),
    glm: ids.filter((i) => i.toLowerCase().includes("glm")),
    all: ids,
  });
}

function buildUserContent(prompt, input) {
  const facts = Object.entries(input)
    .filter(([, v]) => v != null && String(v).length)
    .map(([k, v]) => `${k}: ${v}`)
    .join("\n");
  return facts ? `${prompt}\n\n${facts}` : prompt;
}

// ─── identity: install token OR bootstrap ─────────────────────────────────────

async function resolveIdentity(bearer, env, ip) {
  if (!bearer) return null;
  const claims = await verifyInstallToken(bearer, env);
  if (claims) return { kind: "install", key: `inst:${claims.sub}` };
  if (timingSafeEqual(bearer, env.SECONDLOOK_CLIENT_TOKEN || "")) return { kind: "bootstrap", key: `boot:${ip}` };
  return null;
}

async function registerInstall(request, env, ip) {
  let body;
  try { body = await request.json(); } catch { return json({ error: "bad json" }, 400); }
  const installId = String(body.installId || "").slice(0, 64);
  if (!/^[A-Za-z0-9._\-]{8,64}$/.test(installId)) return json({ error: "bad installId" }, 400);

  // DeviceCheck verification — enforced only when the key is configured.
  let attested = false;
  if (env.DEVICECHECK_KEY_ID && env.DEVICECHECK_KEY && env.APPLE_TEAM_ID) {
    if (!body.deviceToken) return json({ error: "deviceToken required" }, 400);
    attested = await verifyDeviceCheck(String(body.deviceToken), env).catch((e) => {
      console.log("devicecheck error:", String(e));
      return false;
    });
    if (!attested) return json({ error: "device attestation failed" }, 403);
  } else {
    console.log("register: DeviceCheck not configured — accepting on bootstrap token");
  }

  const ttlSeconds = 24 * 3600;
  const exp = Math.floor(Date.now() / 1000) + ttlSeconds;
  const token = await signInstallToken({ sub: installId, exp, att: attested ? 1 : 0 }, env);
  return json({ token, expiresAt: exp * 1000 });
}

// Minimal HS256 JWT (header.payload.sig), enough for a first-party install token.
async function signInstallToken(claims, env) {
  const secret = env.INSTALL_TOKEN_SECRET;
  if (!secret) throw new Error("INSTALL_TOKEN_SECRET not set");
  const header = b64url(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const payload = b64url(JSON.stringify(claims));
  const sig = await hmac(`${header}.${payload}`, secret);
  return `${header}.${payload}.${sig}`;
}

async function verifyInstallToken(token, env) {
  const secret = env.INSTALL_TOKEN_SECRET;
  if (!secret || !token || token.split(".").length !== 3) return null;
  const [header, payload, sig] = token.split(".");
  const expected = await hmac(`${header}.${payload}`, secret);
  if (!timingSafeEqual(sig, expected)) return null;
  let claims;
  try { claims = JSON.parse(atobUrl(payload)); } catch { return null; }
  if (!claims.exp || claims.exp < Math.floor(Date.now() / 1000)) return null;
  return claims;
}

async function verifyDeviceCheck(deviceToken, env) {
  const jwt = await appleDeviceCheckJWT(env);
  const body = JSON.stringify({
    device_token: deviceToken,
    transaction_id: crypto.randomUUID(),
    timestamp: Date.now(), // milliseconds
  });
  // A token from a dev/TestFlight build validates against the development host;
  // an App Store build against production. Try production first, then dev.
  for (const host of ["api.devicecheck.apple.com", "api.development.devicecheck.apple.com"]) {
    const res = await fetch(`https://${host}/v1/validate_device_token`, {
      method: "POST",
      headers: { Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
      body,
    });
    if (res.status === 200) return true; // genuine Apple device
    // 400 "Failed to find bit state" also means a valid token (just no stored bits).
    const text = (await res.text().catch(() => "")).toLowerCase();
    if (res.status === 400 && text.includes("bit state")) return true;
  }
  return false;
}

async function appleDeviceCheckJWT(env) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "ES256", kid: env.DEVICECHECK_KEY_ID }));
  const payload = b64url(JSON.stringify({ iss: env.APPLE_TEAM_ID, iat: now, exp: now + 600 }));
  const key = await importES256(env.DEVICECHECK_KEY);
  const sigBuf = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" }, key,
    new TextEncoder().encode(`${header}.${payload}`)
  );
  return `${header}.${payload}.${b64urlBytes(new Uint8Array(sigBuf))}`;
}

async function importES256(pem) {
  const der = Uint8Array.from(
    atob(pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "")),
    (c) => c.charCodeAt(0)
  );
  return crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
}

// ─── Durable Object rate limiter (atomic, global) ─────────────────────────────

async function checkRateLimit(env, key, limits) {
  try {
    const id = env.RATE_LIMITER.idFromName(key);
    const stub = env.RATE_LIMITER.get(id);
    const res = await stub.fetch("https://rl/check", {
      method: "POST",
      body: JSON.stringify(limits),
    });
    return await res.json();
  } catch (e) {
    console.log("rate limiter unavailable:", String(e));
    return { allowed: true }; // fail open — never block a paying request on infra
  }
}

export class RateLimiter {
  constructor(ctx) { this.ctx = ctx; }

  async fetch(request) {
    const parsed = await request.json().catch(() => ({}));
    const minLimit = Number.isFinite(parsed.minLimit) ? parsed.minLimit : 10;
    const dayLimit = Number.isFinite(parsed.dayLimit) ? parsed.dayLimit : 100;
    const now = Date.now();
    const nowSec = Math.floor(now / 1000);
    const minKey = `m:${Math.floor(now / 60000)}`;
    const dayKey = `d:${Math.floor(now / 86400000)}`;

    const stored = await this.ctx.storage.get([minKey, dayKey]);
    const m = stored.get(minKey) || 0;
    const d = stored.get(dayKey) || 0;

    if (m >= minLimit) return Response.json({ allowed: false, scope: "minute", retryAfter: 60 - (nowSec % 60) });
    if (d >= dayLimit) return Response.json({ allowed: false, scope: "day", retryAfter: 86400 - (nowSec % 86400) });

    await this.ctx.storage.put({ [minKey]: m + 1, [dayKey]: d + 1 });
    this.ctx.storage.setAlarm(now + 3600_000);
    return Response.json({ allowed: true, minRemaining: minLimit - m - 1, dayRemaining: dayLimit - d - 1 });
  }

  async alarm() {
    const nowMin = Math.floor(Date.now() / 60000);
    const nowDay = Math.floor(Date.now() / 86400000);
    const all = await this.ctx.storage.list();
    const stale = [];
    for (const k of all.keys()) {
      const [t, n] = k.split(":");
      if (t === "m" && Number(n) < nowMin - 5) stale.push(k);
      if (t === "d" && Number(n) < nowDay - 2) stale.push(k);
    }
    if (stale.length) await this.ctx.storage.delete(stale);
  }
}

// ─── small crypto / encoding helpers ─────────────────────────────────────────

async function hash(s) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function hmac(data, secret) {
  const key = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(data));
  return b64urlBytes(new Uint8Array(sig));
}

function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

const b64url = (s) => btoa(unescape(encodeURIComponent(s))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const b64urlBytes = (bytes) => btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const atobUrl = (s) => decodeURIComponent(escape(atob(s.replace(/-/g, "+").replace(/_/g, "/"))));

function json(obj, status = 200, maxAge = 0, extraHeaders = {}) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...(maxAge ? { "Cache-Control": `max-age=${maxAge}` } : {}),
      ...extraHeaders,
    },
  });
}
