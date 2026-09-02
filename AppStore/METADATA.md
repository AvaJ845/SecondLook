# App Store — SecondLook

Paste-ready listing metadata. Rules per the $50K ASO Playbook: Apple indexes
**App Name + Subtitle + Keywords as one concatenated string** — every word spent
once, no repeats across the three fields.

## Identity — Discovery (keyword-first)

- **App Store Name (≤30):** `Job Scam Checker - SecondLook`  *(29 chars — primary keyword FIRST, brand second)*
  - Home-screen name (`CFBundleDisplayName`) stays **`SecondLook`**. Same pattern as "Habit Tracker - Habit Kit" showing as "Habit Kit" on device.
  - As an unknown indie we cannot spend the store name on the brand. Never ship the bare `SecondLook` store name (see Naming Council — the token is shared with "SecondLook - Style Scanner" and a U. Michigan medical study-aid franchise).
- **Subtitle (≤30):** `Spot fake offers & recruiters`  *(29 chars — all new words, none repeated from the Name)*
  - Alts: `Check recruiter texts & offers` *(29 — "check" stems near "checker", avoid)* · `Fake offer & recruiter warning` *(30)* · `Vet a recruiter or job offer` *(28 — repeats "job")*
- **Bundle ID:** `com.avaresearch.secondlook`
- **Primary category:** Utilities  ·  **Secondary:** Business
- **Age rating:** 4+ (no objectionable content)
- **Price:** Free to download. Optional **SecondLook Plus** auto-renewable
  subscription — **$3.99/month** or **$24.99/year** (≈ $2.08/mo, ~48% off),
  7-day free trial on both. Group `SecondLook Plus`; products
  `com.avaresearch.secondlook.plus.{monthly,yearly}`.
  - Deliberately at the **low end** of the comp set (StopScam / Scam Scanner are
    $4.99/mo; NoClick runs $4.99/**week**). The brand promise is "we don't
    extract from you" — the price shouldn't either.
  - Free is safety-complete: unlimited standard on-device checks, screenshot
    OCR, hiring-stage context, full findings, recent history, 2 Deep AI
    Checks/month. Plus adds 20 Deep AI Checks/month, full saved history, deeper
    analysis. **Plus never gates basic safety.**

## Keywords (≤100) — the hidden App Store Connect array

`fraud,phishing,employment,hiring,career,work,message,text,email,dm,interview,onboarding,letter,wire`  *(99 chars)*

Rules applied: comma-separated, **no spaces**, **no word repeated** from Name or
Subtitle, **singulars only**, **no competitor or platform names**. Apple indexes
Name + Subtitle + Keywords as one string, so these assemble into phrases like:

**Combinations harvested:** `job scam checker`, `fake job`, `employment scam`,
`recruiter fraud`, `hiring scam`, `career scam`, `fake offer`, `job offer letter`,
`interview scam`, `phishing email`, `scam text message`, `wire fraud`,
`work from home scam`, `recruiter scam`, `fake recruiter`

**Deliberately excluded:**
- `verified` / `legit` / `legitimate` / `trust` / `background check` — SecondLook
  flags patterns and **never confirms** a company or person is real or fake.
  Using these would overpromise and invite an App Review question (same
  discipline as Kestrel dropping `forecast`).
- Competitor/platform names — `ScamAdviser`, `Sniff Job`, `StopScam`,
  `Malwarebytes`, `LinkedIn`, `Indeed`, `Telegram`, `WhatsApp` — Apple rejects
  third-party trademarks in the keyword field.
- `identity theft` / `credit` / `SSN` — adjacent but out of scope; would
  misrepresent what the app does.
- `guarantee` / `block` / `protect` (as a promise) — implies enforcement the app
  doesn't perform.

## Promotional text (≤170)

Got a recruiter message that feels off? SecondLook checks it against the patterns behind fake job offers — on your device — and tells you, in plain words, what's unusual for your hiring stage.

## Description

Job scams hit 1 in 3 U.S. adults — and nearly half of Gen Z. The average loss when one lands is around $8,900. Scammers lean on real company names precisely because you don't expect them.

SecondLook is a fast, private gut-check for any job message. Paste a recruiter email or text, or drop in a screenshot, pick where you are in the hiring process, and get a plain-language report on what doesn't add up.

**Explainable, not a black box**
• Every flag says exactly what was found, why it's unusual, and what to do next — no mystery "scam score."
• Checks for the real patterns: payment to get started, gift-card or wire requests, SSN or bank details asked for too early, fake-check schemes, interviews only over chat apps, offers with no interview, lookalike sender domains, pressure and urgency.
• Weighs everything against your hiring stage — an SSN request is routine onboarding paperwork but alarming at first contact.

**Private by default**
• The message and any screenshot are read entirely on your device. No account. No tracking.
• Saved checks store only which flags matched and the date — never the message text.
• One optional feature, "Deep AI check," sends a screenshot and text to an AI service for a closer read — only when you tap it and accept a one-time explanation. Everything else stays on your phone.

**Made to share**
• Forward this to a friend who's job hunting. Checking a suspicious offer takes ten seconds.

SecondLook points out patterns commonly seen in job scams. It can't confirm whether any message, company, or person is legitimate, and a clean result isn't a guarantee. When money, documents, or personal numbers are involved, verify the employer independently.

## What's New (1.0)

First release. Paste a job message or import a screenshot, pick your hiring stage, and get an explainable report on what's unusual — read entirely on your device. Includes stage-aware red-flag rules, an on-device link check against real careers and applicant-tracking sites, and an optional AI deep check you control.

Also: a company reality check — when a message name-drops a big employer, SecondLook compares its links to that employer's real careers site, all from a bundled offline list; a "Spot the scam" practice mode and a browsable guide to every pattern; a Control Center check and a Home Screen widget; "Send a safe copy" to forward a suspicious message with your personal numbers stripped; and VoiceOver support — every flag is announced with its severity and its reason.

## URLs

- **Support / Marketing:** https://avaj845.github.io/SecondLook/ (`docs/` in the repo — enable GitHub Pages on the `dev` branch `/docs` folder)
- **Privacy Policy:** https://avaj845.github.io/SecondLook/privacy.html
- **Terms of Use (EULA):** https://avaj845.github.io/SecondLook/terms.html (or Apple standard EULA)

## Screenshots (6.9" — 1320×2868) — Conversion

Lead with the payoff (real captured UI beats abstract — playbook A/B evidence):

1. **The report** — "See what's off about a job message in seconds." Real report: red banner *"Several things don't line up"* + severity chips + first finding.
2. **Explainable flag** — "Every flag says why — and what to do." An expanded finding card.
3. **Stage-aware** — "Normal at onboarding. Alarming at first contact." Stage picker changing the read on an SSN request.
4. **Deep AI check (opt-in)** — "Want a closer look? Send it to AI — on your terms." The consent card.
5. **Private by default** — "Your message never leaves your phone unless you say so." The privacy screen.
6. *(optional)* **Share it** — "Forward it to a friend who's job hunting."

App icon: `AppStore/AppIcon-1024.png` (1024×1024, no alpha).

## App Privacy (nutrition label)

- **Data collected — default:** None. No account, no analytics/tracking SDKs. No network calls.
- **Data collected — only if the user enables "Deep AI check":** *Other User Content* (the screenshot + message text for that one request), used for **App Functionality only**, **not linked** to identity, **not used for tracking**. Matches `SecondLook/Resources/PrivacyInfo.xcprivacy`.

## Review notes (paste into App Review)

SecondLook is a **safety and education utility** for job seekers. It runs an
on-device rule check over a job message (text the user pastes or OCR from a
screenshot they import) and reports which known job-scam patterns it matched,
with a plain-language explanation of each.

It **does not** confirm or deny that any company, recruiter, or person is
legitimate or fraudulent — every surface states it flags patterns only. There is
no account, no user-generated content shared between users, no real-money
activity.

The default flow is entirely on-device and makes no network requests. One
clearly-labeled optional feature, "Deep AI check," transmits the current
screenshot and message text to our backend (a Cloudflare Worker that proxies a
third-party model) — only on an explicit tap, after a one-time consent screen,
and it is revocable in About → AI. This is declared in the privacy manifest as
Other User Content for App Functionality.
