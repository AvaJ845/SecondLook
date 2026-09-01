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
- **Growth loop → on-device `ImageRenderer` ShareCard** (overall read + finding
  titles + severities + disclaimer + URL; no quotes, no domains, no identity) +
  a "Check with SecondLook" App Intent. **SHIP** the card; Reshape the Intent
  into the same release.

## Open questions

- Ship the domain reference list in-app (current) vs. a signed, updatable bundle?
- Localization beyond English for OCR + rules.
- Do we add a lightweight "what a real offer letter looks like" explainer screen?
- App Store review: position as "educational / informational," not "security."
- Legal pass owner + timeline for the user-facing copy.
