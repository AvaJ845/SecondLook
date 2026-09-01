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

## What crosses the wire

Only the app's own rule metadata: **which SecondLook signals fired** and the
**hiring stage**. The user's message text, screenshots, email addresses, names,
and domains are stripped by the app before the request is built
(`SecondLook/Kit/AI/AIAdvisor.swift`). The system prompts additionally forbid the
model from naming or accusing any real company or person.

## Status

**Deployed:** `https://secondlook-ai.divine-mountain-8173.workers.dev`
(`GET /health` → `{"ok":true}`). `SECONDLOOK_CLIENT_TOKEN` is set and the app's
`Config/AIConfig.plist` points at it.

**Pending:** the provider secrets. Until they're added, `/v1/generate` returns
`502 all providers failed` and the app falls back to on-device text.

```sh
cd backend
npx wrangler secret put OPENROUTER_API_KEY   # sk-or-v1-…  (vision models + GLM)
npx wrangler secret put NVIDIA_API_KEY       # nvapi-…     (gpt-oss fallback for text tasks)
# already set: SECONDLOOK_CLIENT_TOKEN
```

Verify:

```sh
TOKEN=<the SECONDLOOK_CLIENT_TOKEN>
curl -s https://secondlook-ai.divine-mountain-8173.workers.dev/v1/generate \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"task":"plainSummary","tier":"fast","input":{"hiring_stage":"First contact","signals_that_fired":"Major red flag: Asks you to pay to get the job"},"prompt":"summarize"}'
```

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
