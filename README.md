# SecondLook

Share a job message or a screenshot in, and SecondLook takes a second look before
you reply — checking it on-device against the patterns behind fake job offers and
explaining, in plain language, what's unusual for where you are in the hiring
process.

33% of U.S. adults have hit a job scam (44% of Gen Z), with an average loss of
$8,900 when it lands. SecondLook is a fast, private gut-check you can forward to a
friend who's job-hunting right now.

## How it works

1. **Bring the message in** — paste text, import a screenshot (read on-device with
   the Vision framework), use the share sheet from Mail / Messages / a browser, or
   run the "Check this with SecondLook" Shortcut / Siri phrase.
2. **Pick your hiring stage** — first contact, interviewing, offer, or onboarding.
   The same request can be routine at one stage and a red flag at another.
3. **Read the report** — an overall read plus an explainable list of findings.
   Every finding says *why* it stands out and *what to do*. There is no black-box
   score.
4. **Link check** — any domains in the message are compared on-device to a bundled
   list of real careers and applicant-tracking sites, and checked for brand
   lookalikes (`amaz0n-hiring.com`). SecondLook never opens the links.
5. **Share it** — "Share this result" renders a card (on device) with the overall
   read and the finding titles — **no message text, no names, no links from the
   message** — for a friend who's job hunting.

## Plain-language layer (AI)

The report's "In plain terms" card — a short summary and a suggested reply — is
built from the deterministic findings. It's phrased by SecondLook's AI backend
(`backend/`, a Cloudflare Worker, the Pitchwire gateway pattern) when one is
configured, and written on-device from templates otherwise.

The backend is sent **only which rules fired and the hiring stage** — never your
message text, a screenshot, an email address, a name, or a domain. With no
`Config/AIConfig.plist` the app is fully offline and makes no network calls.

### Deep AI check (opt-in)

The report has one optional control — **Deep AI check** — that works differently:
it sends the screenshot and message text to a vision model on the backend for a
closer read. It runs only when you tap it and accept a one-time explanation, and
it's revocable in About → AI. This is the only path that transmits your message
content; it's declared in the privacy manifest accordingly. See
`SecondLook/Kit/AI/DeepCheck.swift` and `backend/`.

## Privacy (the whole point)

An anti-scam app that hoards the data it warns you about would be a bad joke.

- The message and any screenshot are processed **entirely on-device**. The app
  makes **no network calls**. No account, no analytics.
- Imported screenshots are **not stored** — only the extracted text, in the editor.
- **Saved checks hold no message text** — only which rules matched, the stage, and
  the date. SSNs and similar numbers are stripped from on-screen quotes.
- See `SecondLook/Resources/PrivacyInfo.xcprivacy` and the in-app Privacy screen.

## What SecondLook does *not* do

It flags patterns. It does not — and cannot — confirm that any message, company,
or person is legitimate or fraudulent, and a clean result is not a guarantee. It
never states that a named company is running a scam; a lookalike domain is
reported as "resembles X, verify independently." Copy needs a legal pass before
ship.

## Build

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
xcodebuild -scheme SecondLook -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
open SecondLook.xcodeproj
```

## Layout

| Path | What |
| --- | --- |
| `SecondLook/Kit/` | The engine — models, rule catalog, domain checker, OCR. Pure, no I/O. Shared with the share extension. |
| `SecondLook/Kit/AI/` | AI gateway/client seam (Pitchwire pattern), `AIAdvisor` with on-device fallbacks. |
| `backend/` | `secondlook-ai` Cloudflare Worker — separate from Pitchwire's. |
| `SecondLook/Kit/UI/` | Presentational components shared by the app and the share extension. |
| `SecondLook/Features/` | App screens: Analyze, Report, History, About. |
| `SecondLook/Store/` | `HistoryStore` — saved checks (no message text). |
| `ShareExtension/` | Share-sheet target; runs the same engine inline. |
| `SecondLookTests/` | Rule-engine and domain-checker tests. |

## Adding a rule

Add a `Rule` to `Rules.all` in `SecondLook/Kit/Rules.swift`. Every rule carries
its own `explanation` and `whatToDo` strings — that *is* the report — plus a
`severity`, the `flaggedStages` where it's a red flag, and an optional
`normalAtStage` / `normalStageNote` for asks that become routine later (SSN at
onboarding). Then add a case to `RuleEngineTests`.
