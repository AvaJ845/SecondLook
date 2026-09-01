# SecondLook — ASO Playbook

Applying the **$50K/Month ASO Playbook** (source deck worked into Kestrel at
`~/Documents/Kestrel/AppStore/ASO_PLAYBOOK.md`). SecondLook is **name decided,
pre-launch**. The game for a zero-budget indie: **rank for terms people type →
convert the tap → compound with reviews.** Every stage must be built — skipping
one breaks the flywheel.

Paste-ready metadata lives in `METADATA.md`.

---

## Engine 1 — Discovery (get found)

- [x] **Primary keyword chosen:** `job scam checker` — Indie Battlefield quadrant.
      Real volume (job scams hit 33% of U.S. adults, 44% of Gen Z; heavy
      2024–2026 press), real but beatable competition: general scam-checker apps
      (ScamAdviser, StopScam, Scam Scanner, Malwarebytes Scam Guard) own
      "scam checker/detector" but **none own "job scam"**; the one job-specific
      competitor, **Sniff Job**, targets job *listing* credibility + résumé
      tools, not received messages.
- [x] **Name (≤30):** `Job Scam Checker - SecondLook` (29) — keyword first, brand second.
- [x] **Subtitle (≤30):** `Spot fake offers & recruiters` (29) — all new words.
- [x] **Keywords (≤100):** `fraud,phishing,employment,hiring,career,work,message,text,email,dm,interview,onboarding,letter,wire` (99) — singular, no spaces, no repeats, no third-party marks.
- [x] **Exclusions locked:** `verified` / `legit` / `background check` / `guarantee`
      — SecondLook flags patterns, never confirms legitimacy. Same discipline as
      Kestrel's `forecast` exclusion. Full list in `METADATA.md`.
- [ ] **After launch:** track monthly rank for `job scam`, `job scam checker`,
      `fake job`, `recruiter scam`, `employment scam`, `scam checker`. Rotate the
      weakest keyword each update.

### Naming Council — 2026-08-31

| Fellow | Lean | Key finding |
|---|---|---|
| Discoverability | **Approve** | Primary keyword `job scam checker` is first in the Name; Subtitle repeats no Name word; Keywords field is 99/100 chars, singular, no repeats. Quadrant is Indie Battlefield, not Trap ("scam checker" alone would be the Trap — crowded by ScamAdviser/StopScam/Malwarebytes) and not Ghost Town (real search volume). |
| Collision | **Revise** | Exact lead-token collision: **"SecondLook - Style Scanner"** (`id6763678050`, Shopping — fashion resale visual search, recent). Plus a **U. Michigan medical study-aid franchise** using "SecondLook" as a suffix: Basic Radiology, Oral Radiology, Histology Complete, Dental Anesthesia, EKG, Fetal Heart Rate — all "*X* - SecondLook" (`id1259825428`, `id1160398439`, `id1010753597`, `id1391829719`, `id1444770017`, `id1455329041`). Function competitor **Sniff Job** (`id6751428299`) — name does not collide. Verdict: keep the name but **never ship the bare-brand store name**; keyword-first only. Different categories (Shopping/Medical vs Utilities) mean a search for "job scam checker" won't surface them. |
| Portfolio | **Approve** | Namespace `com.avaresearch.secondlook` is the right family (AvaResearch utility, not a bird name, not `com.toppupgames.*`) — consistent with Redress/BreachKit/Milestone plain-utility naming. **No portfolio keyword conflict**: "job scam / fake job / recruiter" is unclaimed turf (Redress/BreachKit own settlement/claim; Milestone owns retirement planner; Pitchwire owns PR/journalist). One flag: run a USPTO/TESS check on "SecondLook" for software before any brand spend, given the Michigan franchise + Style Scanner. App-Review guardrail for this category: keywords/subtitle must never imply a verdict about a real entity — enforced by the exclusion list. |

**VERDICT: Revise** — Name is sound. Ship keyword-first only
(`Job Scam Checker - SecondLook`); the bare `SecondLook` store name is off the
table while "SecondLook - Style Scanner" and the medical franchise hold that
token. Keep `SecondLook` as one word for portfolio brand consistency. Do a quick
USPTO/TESS pass on "SecondLook" in software/IC 009 before spending on brand
marketing. Keyword exclusion list stays enforced.

---

## Engine 2 — Conversion (win the tap)

3–5 second visual window. Icon + screenshots carry the whole job.

- [x] **Icon** — `AppStore/AppIcon-1024.png` in place. Must read at home-screen
      size as a "check this message" mark (magnifier + shield/checkmark), not a
      wordmark. Re-review at 60px before submit.
- [ ] **Screenshots — lead with the payoff** (real captured UI; the deck's A/B
      showed a plain real dashboard beating a polished abstract hero):
  1. The report — *"See what's off about a job message in seconds."*
  2. Explainable flag — *"Every flag says why — and what to do."*
  3. Stage-aware — *"Normal at onboarding. Alarming at first contact."*
  4. Deep AI check (opt-in) — *"A closer look — on your terms."*
  5. Private by default — *"Your message never leaves your phone unless you say so."*
  6. *(optional)* Share — *"Forward it to a friend who's job hunting."*
  - Never open on a welcome/empty screen — the report frame is the hero.
- [ ] **App Preview video (optional):** 15–20s — paste a scam text → tap → report
      expands → tap a finding. One real loop, no trailer.
- [ ] **Product-page A/B after launch:** first test = screenshot 1 (report hero
      vs. a "paste any message" explainer frame).

---

## Engine 3 — Momentum (compound with reviews)

Conversion **and** ratings feed the ranking algorithm — this closes the loop back
into Engine 1. Not optional polish.

- [ ] **Ask at the happy moment.** Not launch, not onboarding, not after an OCR
      failure or the consent sheet. SecondLook's happy moment = **the user
      finishes reading a report that actually found something.** Implement:
      count completed reports where `overall != .clear`; fire the native
      `requestReview` on the **3rd** such report, and again around the **8th**,
      once per app version. (First check is too early — let it prove value.)
- [ ] **The Reply Loop.** Respond to every review. The predictable 1★ —
      *"it flagged my real job as a scam"* — reply: SecondLook flags patterns,
      it never says a company is a scam; ask which message so the rules improve.
      Turn it into a 5★ by shipping the rule fix and saying so.
- [ ] **The Signature Hack.** Support-email footer: *"If SecondLook helped you
      dodge a bad one, a quick review helps other job seekers find it."* Help
      first; the ask rides on reciprocity.
- [ ] **The Roadmap Signal.** ~20 reviews asking for the same thing (Android, an
      email-forwarding address to check offers, a specific scam type) → build it,
      then say so in a reply.
- [ ] **Track rank monthly**, rotate the weakest keyword each update. ASO is a
      multi-year compounding curve (the source app went invisible → Top 5 US over
      ~3 years), not a launch-week sprint.

---

## Growth loop (why this compounds)

keyword rank → impressions on "job scam checker" → report-hero screenshot converts
the tap → user gets a useful result and **forwards it to a job-hunting friend** →
that friend installs and reviews at their happy moment → rating + install velocity
lift rank → room to fight for `job scam` (no "checker") and `fake job`.

The forward-to-a-friend step is the unpaid UA channel — every conversion surface
(promo text, screenshot 6, in-app share) should make it one tap.
