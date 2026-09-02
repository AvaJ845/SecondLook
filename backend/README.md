# SecondLook AI gateway

A single Cloudflare Worker. The app calls it; it holds the provider keys and runs
the failover chain. **Same backend logic as Pitchwire's gateway, but a separate
worker (`secondlook-ai`) with its own deployment, secrets, and task set** — so
nothing here can affect Pitchwire.

```
app ──POST /v1/generate──▶ Worker ──▶ OpenRouter :free  (GLM-5.2, MiniMax, …)
   Bearer <client token>            └▶ NVIDIA NIM       (gpt-oss-120b / -20b)
◀── { text, model, cached, usage } ─┘
```

## Tasks

| task | tier | what it produces |
| --- | --- | --- |
| `plainSummary` | fast | 2–3 sentence read of what stands out, from the signals that fired |
| `replyCoach` | quality | a short, polite reply the job seeker can send |
| `verifyEmployer` | fast | a CHECKS / SEARCHES checklist to verify the employer independently |

Plus a fourth, opt-in task — `deepCheck` — which sends the sanitized message
text and the screenshot to a vision model. SSNs and card/bank numbers are
stripped by the app first (`SecondLook/Kit/Sanitizer.swift`).

## Abuse resistance (P0 #2)

```
app ─POST /v1/register──────────────▶  { token, expiresAt }
     Bearer <BOOTSTRAP>                 · rate limited per IP (4/min, 20/day) so a
     { installId, deviceToken? }          leaked bootstrap token can't farm ids
                                        · deviceToken = Apple DeviceCheck output,
                                          verified with Apple when DEVICECHECK_*
                                          + APPLE_TEAM_ID are set; until then
                                          accepted on the bootstrap token alone
app ─POST /v1/generate──────────────▶  Bearer <install token>  (or bootstrap)
                                        · Content-Length > 3 MB → 413
                                        · every call → per-identity Durable
                                          Object rate limiter (atomic, global)
```

- The **bootstrap token** (`SECONDLOOK_CLIENT_TOKEN`, shipped in the app)
  authorizes only `/v1/register` and works on `/v1/generate` as a
  *tightly* rate-limited fallback.
- The **install token** is a 24h HMAC (`INSTALL_TOKEN_SECRET`) bound to a random
  per-install id — **no user identity, no account**.
- **`RateLimiter` Durable Object** — SQLite-backed (free plan), atomic fixed
  windows. Replaces the old per-PoP `caches.default` counter. Limits: install
  tokens get `deepCheck` 3/min·25/day, text 15/min·120/day; a bare bootstrap
  token gets 2/min·8/day and 6/min·40/day.

## Status

**Deployed:** `https://secondlook-ai.divine-mountain-8173.workers.dev`
(`GET /health` → `{"ok":true}`). Secrets set: `NVIDIA_API_KEY`,
`OPENROUTER_API_KEY`, `SECONDLOOK_CLIENT_TOKEN`, `INSTALL_TOKEN_SECRET`.
Provider chains verified serving real responses.

**Pending — DeviceCheck enforcement:** create an Apple DeviceCheck key (Apple
Developer → Certificates, Identifiers & Profiles → Keys → enable DeviceCheck),
then:

```sh
cd backend
npx wrangler secret put DEVICECHECK_KEY      # the full .p8 file contents (PEM)
npx wrangler secret put DEVICECHECK_KEY_ID   # the 10-char key id
npx wrangler secret put APPLE_TEAM_ID        # your 10-char team id
```

Until then, `/v1/register` mints tokens on the bootstrap token alone — the
Durable Object rate limiter is still fully enforced.

```sh
cd backend
npx wrangler secret put NVIDIA_API_KEY      --name secondlook-ai   # nvapi-…
npx wrangler secret put OPENROUTER_API_KEY  --name secondlook-ai   # sk-or-v1-…
# already set: SECONDLOOK_CLIENT_TOKEN
```

Verify (client token is in `Config/AIConfig.plist`):

```sh
TOKEN=$(/usr/libexec/PlistBuddy -c 'Print :ClientToken' ../Config/AIConfig.plist)
BASE=https://secondlook-ai.divine-mountain-8173.workers.dev

# NVIDIA catalog — confirm the exact ids for kimi-k3 and GLM-5.3-Flash
curl -s "$BASE/v1/models?provider=nvidia" -H "Authorization: Bearer $TOKEN" | python3 -m json.tool

# OpenRouter free models (the fallback tier)
curl -s "$BASE/v1/models" -H "Authorization: Bearer $TOKEN" | python3 -m json.tool

# end-to-end text task
curl -s "$BASE/v1/generate" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"task":"plainSummary","tier":"fast","input":{"hiring_stage":"First contact","signals_that_fired":"Major red flag: Asks you to pay to get the job"},"prompt":"summarize"}'
```

## Model chains

No paid spend: NVIDIA NIM serverless + OpenRouter `:free` only (a hard skip in
the call loop blocks any non-`:free` OpenRouter id).

**Verified working 2026-09-01** by probing the deployed worker with
`POST /v1/generate?only=<id>`:

| id | result |
| --- | --- |
| `nvidia:nvidia/nemotron-3.5-lightning-30b-a3b` | 200, ~6 s (emits a reasoning preamble — `stripReasoning()` removes it) |
| `openrouter:minimax/minimax-m2.7:free` | 200, ~4.5 s, clean |
| `nvidia:moonshotai/kimi-k3` | **hangs 20 s** — was the deepCheck timeout. Removed from every chain. |
| `nvidia:zai-org/glm-5.3-flash` | **404** — never existed on NIM. Removed. |
| other `nvidia:` catalog ids (gemma-3, kimi-k2.6, llama-3.x…) | 404 "not found for account" — this key serves very few |

A model appearing in `/v1/models?provider=nvidia` is **not** proof this key can
call it. Re-probe with `?only=` before trusting a new id.

| chain | models |
| --- | --- |
| text (fast) | **minimax-m2.7:free** → nemotron-3.5-lightning → glm-5.2:free |
| text (quality) | **minimax-m2.7:free** → nemotron-3.5-lightning → glm-5.2:free → nemotron-3-ultra:free |
| deepCheck (vision) | **minimax-m3:free** → gemma-4-31b:free → (text-only last resort on minimax-m2.7:free, image stripped) |
| deepCheck (no image) | **minimax-m2.7:free** → nemotron-3.5-lightning |

### Resilience

- **Circuit breaker** (`breakerOpen`/`breakerTrip`): a model that hangs (504),
  404s, or 5xx's is skipped for 4 min on that isolate — unless it's the last
  option left. Stops one bad model burning the whole time budget on every
  request (exactly what kimi-k3 did).
- **`stripReasoning()`**: removes `<think>…</think>` and, for label-structured
  tasks, anything before the first real label, so a reasoning model's scratchpad
  never reaches the app.

### Time budget

The app waits ~60 s for a `deepCheck` and ~22 s for a text call, then falls back
(deterministic on-device result for text; an error for `deepCheck`). The worker
therefore runs its fallback chain against a **total wall-clock budget**
(`REQUEST_BUDGET_MS` = 50 s for `deepCheck`, 20 s for text) — `planAttempt()`
shortens or skips later attempts so the worker always answers *before* the app
gives up. A whole-chain timeout returns **504** (`"upstream timeout"`), which the
app shows as "took too long — try again", distinct from a real backend error.
This is why the vision chain is only two models: a slow first model plus one
fallback is all that fits. `npm test` covers the budget math.

## Redeploy

```sh
cd backend && npx wrangler deploy
```

Then point the app at it: copy `Config/AIConfig.example.plist` to
`Config/AIConfig.plist` and set `BaseURL` to the deployed `*.workers.dev` URL and
`ClientToken` to the `SECONDLOOK_CLIENT_TOKEN` you set. Re-run `xcodegen generate`.

With no `AIConfig.plist`, the app runs fully offline on deterministic text and
makes no network calls.

## Notes carried over from Pitchwire's gateway

- Provider keys live in Worker secrets, never in the app.
- Identical requests are cached 6h (Cache API).
- Per-IP rate limit (default 20/min) as light abuse protection.
- `?only=<model>` forces one provider for testing.
- Model IDs drift — z.ai renames its flash tier, NVIDIA retires models on a
  schedule. If calls start 4xx-ing, check the provider's `/v1/models` and update
  the constants at the top of `src/worker.js`.
- z.ai direct is Aliyun-fronted and blocked from Cloudflare egress IPs — the
  `glm-*-flash` entries are dormant on CF and light up on a non-CF host.
