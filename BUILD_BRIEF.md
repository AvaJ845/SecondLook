# SecondLook — build brief

## C-suite decision: GO

- **Dan (COO):** Feasible. The hard part is restraint — this is "is this ask, at
  this stage, normal," not "is this company legit." On-device OCR + a rules-first
  classifier is buildable fast. **Trap to avoid: a verified-employer database** —
  a maintenance and liability sink. Not v1.
- **Becky (CCO):** Market is wide open, timing is right. 33% of U.S. adults have
  hit a job scam (Gen Z 44%), avg loss $8,900. Growth loop is "forward this to a
  friend job-hunting right now" — shareable by design, no paid UA for v1.
- **Chandler (CFO):** Cheap if it stays on-device — no server bill because we
  never touch PII. **Flag patterns, never say "Company X is running a scam"** —
  defamation exposure. Budget a legal pass on the copy before ship.
- **Klaus (CEO):** Go. Build brief, standard shape.

## North Star

Share a screenshot or forwarded email into the app → on-device OCR + explainable
red-flag rules (not a black-box score) → plain-language report on what's unusual
for this hiring stage → optional domain check against real career sites.

## MVP (this scaffold)

- [x] Paste text / import screenshot / share-sheet intake
- [x] On-device OCR (Vision), no upload
- [x] Hiring-stage selector that re-weights findings
- [x] ~18 explainable rules, each with "why" + "what to do"
- [x] Stage-aware demotion (SSN/bank/ID = routine at onboarding, with caveat)
- [x] On-device domain check: known ATS/careers hosts, free-mail, brand lookalikes
      (incl. character-swap `amaz0n`), no network
- [x] Hedged overall read — describes the message, never judges a company
- [x] Saved checks store rule IDs + stage + date only; never message text
- [x] Redaction of SSN / long digit runs / DOB from on-screen quotes
- [x] Privacy manifest + in-app privacy screen + FTC / identitytheft.gov links
- [x] Share extension runs the same engine inline
- [x] Unit tests for the engine and domain checker

## Per-Fellow directives

- **Mei (privacy) — load-bearing:** Nothing sensitive leaves the device; the app
  makes no network calls; saved history stores no message text. Done. Guard this
  in every future change.
- **Rules/heuristics:** Keep every rule explainable — the `explanation` and
  `whatToDo` strings *are* the report. No scoring model.
- **Copy (legal-sensitive):** Never assert a named company is fraudulent.
  Lookalike domains are "resembles X, verify independently." Overall read is
  hedged. **Copy still needs a legal pass before ship.**
- **Content:** Rule catalog is deliberately small and high-signal. Expand from
  real FTC / FBI IC3 job-scam typologies, not guesses.

## Slice 1 — Fellows continue (AI baked in)

North Star unchanged. Slice 1 adds a plain-language layer on top of the
deterministic engine, using the **Pitchwire AI backend pattern** — a separate
Cloudflare Worker (`secondlook-ai`), its own secrets and task set, zero shared
surface with Pitchwire.

### AI architecture (ported from Pitchwire, `SecondLook/Kit/AI/`)
- `AIGateway` protocol boundary · `AIClient` single seam · `AIConfiguration`
  (baseURL + scoped `clientToken`, **never a provider key**) · `HTTPGateway`
  (talks only to our Worker) · `OfflineGateway` (default) · `MockAIGateway`
  (DEBUG) · `LLMLog` + telemetry + `Redaction` for secrets.
- Fixed `AITask` set: `plainSummary`, `replyCoach`, `verifyEmployer`. No
  free-form prompts from call sites.
- **Every task has a deterministic on-device fallback** (`AIAdvisor`). With no
  `Config/AIConfig.plist`, the app is 100% offline and makes no network calls —
  the privacy manifest stays literally true for the shipping default.

### The privacy hardening (SecondLook-specific)
What can reach the backend: **only the names of the SecondLook rules that fired
plus the hiring stage** — all app-authored strings. The user's message text,
screenshots, email addresses, names, and domains are stripped before the request
is built. System prompts additionally forbid the model from naming or accusing
any real company or person. This is the resolution of the "no data leaves the
device" tension — Mei signs off because no user content is ever in the payload.

### Shipped in Slice 1
- [x] Full AI layer + `secondlook-ai` Worker (`backend/`)
- [x] "In plain terms" card in the report — summary + "what you could say back"
- [x] Honest provenance caption (generated vs. on-device) + AI status in About
- [x] DEBUG AI call-log viewer
- [x] Privacy manifest + Privacy screen updated for the optional backend
- [x] 7 AI-layer tests (config mapping, secret redaction, offline fallback,
      mock-gateway generation)

### Deep AI check (opt-in, multimodal) — added
- `secondlook-ai` Worker **deployed**: `https://secondlook-ai.divine-mountain-8173.workers.dev`
  (`SECONDLOOK_CLIENT_TOKEN` set; provider keys pending — see backend/README).
- `Config/AIConfig.plist` written (gitignored) → app reports "AI backend".
- New `deepCheck` task: sends the screenshot (downscaled JPEG) + message text to
  an OpenRouter vision model (llama-3.2-vision / mistral-small / qwen-2.5-vl /
  gemini-2.0-flash chain; text-only fallback on a strong model). Returns a
  READ / CONCERNS / REPLY / VERIFY block, parsed into `DeepCheckResult`.
- App: `DeepCheckSection` under the report, behind a one-time consent sheet
  (`secondlook.deepcheck.consented`), revocable in About → AI. Only shows when a
  backend is configured and there's content.
- Privacy: default flow unchanged (on-device). Deep check is the one path that
  transmits user content — declared in the privacy manifest as Other User
  Content, app-functionality only, not linked to identity, not tracking.
- 10 AI-layer tests (added deepCheck parsing + not-configured + mock paths).

### Slice 2 candidates (not built)
- `verifyEmployer` wired into the UI (checklist card) — task + prompts exist
- Re-check / follow-up: save a thread, re-run as new messages arrive
- First-run onboarding; iPad layout; localization (OCR + rules + prompts)
- Paid fallback + a durable rate-limit store on the Worker before public launch
- Verify the OpenRouter vision model IDs against the live catalog; tune the chain

## Slice 2 — onboarding + subscription (shipped)

- 4-screen first-run onboarding with the SecondLook hand signature (Navy→Teal,
  per-screen gesture, Reduce Motion aware). First-launch only; Skip == finish;
  no account, no permissions, no paywall in the flow. iPhone + iPad.
- StoreKit 2: `SubscriptionManager` + `Entitlements` (single source of truth) +
  `DeepCheckQuota` (keychain-backed monthly ledger, survives reinstall).
- **SecondLook Plus — $3.99/month or $24.99/year (≈ $2.08/mo), 7-day free trial.**
  Deliberately low-end vs the comp set ($4.99/mo elsewhere; NoClick $4.99/week).
  Free is safety-complete + 2 Deep AI Checks/mo; Plus = 20/mo + full history +
  deeper analysis. Plus never gates basic safety.
- Paywall never shown in onboarding. `PlusUpsellSheet` once after the first
  completed check; full `PaywallView` on Deep-AI-quota exhaustion and from About.
- Tab "Saved" → "History"; free shows recent window, Plus shows all.
- Privacy copy: "the message never leaves your device" → "your normal check
  stays on your device".

## North Star for the P0-blocker fixes (Fellows, concept mode)

> The standard check runs entirely on device, explains itself with named rules
> not a score, and makes **zero** network requests in the shipping build — a
> five-part claim no incumbent (StopScam, ScamAdviser, Bitdefender Scamio,
> Malwarebytes Scam Guard, NoClick) can honestly make. Every P0 fix must
> strengthen that claim.

Verdicts:
- **Redaction → a `Sanitized` boundary type** — ✅ **DONE.** `Kit/Sanitizer.swift`
  (was `Redaction.swift`): `Sanitized` wrapper (only `Sanitizer.sanitized(_:)`
  makes one); `RuleHit.init` sanitizes every quote so no detector can bypass it
  (fixed the hand-built `personal_email` path); `DeepChecker.run` sanitizes
  `payload["text"]` before it leaves the device. Patterns broadened: SSN any
  separator / bare / labeled, cards (spaced/dashed/bare/amex), IBAN, labeled
  bank/routing, numeric + prose DOB, plus the existing secret patterns.
  19-case adversarial corpus + over-redaction guard + end-to-end engine test in
  `SanitizerTests.swift`. Screenshot pixels still can't be scrubbed — consent
  copy says so.
- **Backend abuse** — ✅ **scoped cut DONE.**
  - `RateLimiter` **Durable Object** (SQLite, free plan) — atomic global
    per-identity fixed-window limiter, replaces the racy per-PoP
    `caches.default` counter. Verified: bootstrap text token 429s on the 7th
    request/min exactly as configured.
  - `/v1/register` mints a **24h HMAC install token** bound to a random
    per-install id (keychain, survives reinstall) — **no account, no identity**.
    `CredentialProvider` actor registers lazily on the first backend call,
    caches + refreshes, serializes concurrent callers, falls back to the
    bootstrap token if the backend is unreachable. `HTTPGateway` retries once
    on 401.
  - **DeviceCheck** attestation is wired end-to-end (`DeviceCheckAttestor`,
    `/v1/register` Apple verification) but **enforcement is gated on the
    `DEVICECHECK_*` + `APPLE_TEAM_ID` secrets** — add the key and it turns on
    with no app update. Sim has no DeviceCheck → falls back cleanly.
  - `INSTALL_TOKEN_SECRET` set. `SECONDLOOK_CLIENT_TOKEN` is now the bootstrap.
  - **Deferred:** full App Attest per-key crypto; a server-side monthly quota
    mirror. Adding user accounts stays **CUT**.
  - 6 `CredentialProviderTests` (cache, concurrency, expiry, 401 refresh,
    bootstrap fallback). E2E register→generate confirmed in the sim.
- **Growth loop → on-device ShareCard + App Intent** — ✅ **DONE.**
  - `ShareCard` (Kit) is built only from the overall read + finding *titles* +
    severities + stage. **No field exists for a quote, domain, email, or name** —
    a share can't leak the message by construction. `plainText()` fallback.
  - `ShareCardView` — fixed 1080×1350, fixed light palette (navy on mint/white,
    theme-independent), severity = SF Symbol + the severity word, never colour
    alone. `ShareCardRenderer` → PNG on device, < 400 KB.
  - `ShareResultSheet` on the report ("Share this result") — always shows the
    exact card before it's sent, then a `ShareLink` vending a `SharedResult`
    (`Transferable`: PNG + plain-text fallback). One artifact, not three.
  - `CheckMessageIntent` + `SecondLookShortcuts` — "Check this with SecondLook"
    Siri phrase / Shortcuts action; stages the text locally (`PendingCheck`),
    `AnalyzeView` consumes it on appear. Inbound share extension + this + the
    share-out card = the loop.
  - 7 `ShareCardTests` (no content leak, capped findings, clean/strong copy,
    stage label, plain-text). Verified visually in the sim.

## Cloud security pass (Fellows) — 2026-08-31

Reviewed `backend/src/worker.js`. Fixed:
- **Install-token farming** — `/v1/register` had no rate limit, so a leaked
  bootstrap token could mint unlimited install ids and sidestep the
  per-identity limiter. Now DO-rate-limited per IP (4/min, 20/day).
- **Vestigial `/v1/register/challenge`** removed — App-Attest-style challenge,
  unused by the DeviceCheck flow.
- **Info leak** — the "all providers failed" 502 echoed upstream error text and
  model ids to the client. Now logged server-side only; client gets a bare error.
- **Body-size guard** — `Content-Length > 3 MB` → 413 (the app caps images ~0.9 MB).
- **Timing-safe** bootstrap-token comparison in `resolveIdentity` / `/v1/register`.
- **DO limiter** — `minLimit`/`dayLimit` now validated + defaulted.
Deferred (unchanged): full App Attest per-key crypto; server-side quota mirror;
JWT `jti`/revocation on the 24h install token (rate-limited, carries no PII).

## Dead code / docs cleanup — 2026-08-31

- `DeepCheckResult.model` + `.rawText`, `DeepChecker.parse(_:model:)` param —
  removed (model is already in AIClient telemetry).
- `SubscriptionManager.subscriptionGroupID` — removed (StoreKit resolves the
  group from the products).
- `OnboardingHand` — rewritten as a single SF Symbol per screen (`hand.wave.fill`
  → `hand.point.up.left.fill` → `hand.raised.fill` → `hand.tap.fill`) with the
  Navy→Teal gradient, matching the Hummingbird onboarding style. Dropped the
  geometric composite shape, the mint disc, and the coral wave arcs.
- Marketing/legal site added at `docs/` (index / privacy / terms), modeled on
  Hummingbird's — serve via GitHub Pages at `avaj845.github.io/SecondLook/`.

## Fellow verdict — is the app at its North Star?

> **North Star:** the standard check is on-device, explainable, and makes zero
> network requests; the optional AI tier never breaks the free private product
> or adds an account; a share moves a redacted artifact, never the message.

**At the North Star.** The rule engine is pure and offline (`RuleEngine` — no
I/O); the `Sanitizer` boundary is enforced by `RuleHit.init` and on the
deep-check payload; the AI tier degrades to deterministic templates and never
gates safety; the backend uses per-install tokens with **no account**; the
`ShareCard` has no field that can hold message content. Remaining gaps are
config, not architecture: create the DeviceCheck key, wire the real App Store
URL, publish `docs/`.

## Open questions

- Ship the domain reference list in-app (current) vs. a signed, updatable bundle?
- Localization beyond English for OCR + rules.
- Do we add a lightweight "what a real offer letter looks like" explainer screen?
- App Store review: position as "educational / informational," not "security."
- Legal pass owner + timeline for the user-facing copy.
