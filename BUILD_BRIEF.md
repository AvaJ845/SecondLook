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

## Open questions

- Ship the domain reference list in-app (current) vs. a signed, updatable bundle?
- Localization beyond English for OCR + rules.
- Do we add a lightweight "what a real offer letter looks like" explainer screen?
- App Store review: position as "educational / informational," not "security."
- Legal pass owner + timeline for the user-facing copy.
