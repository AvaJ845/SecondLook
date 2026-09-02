# App Store screenshots

Captured on **iPhone 17 Pro Max (6.9")** — native **1320 × 2868**, which is
exactly the App Store Connect 6.9" slot. Upload these to the 6.9" display size;
App Store Connect derives the smaller sizes.

| # | Frame | Suggested caption |
|---|---|---|
| 1 | Onboarding | Before you reply, take a second look. |
| 2 | Check screen with a scam message pasted | Paste a recruiter message or drop in a screenshot. |
| 3 | The report | Every flag says what's wrong, why, and what to do — no black-box score. |
| 4 | Share sheet | Share the check with a friend — never the message. |

Regenerate: build for the Pro Max sim, then
`xcrun simctl launch <id> com.avaresearch.secondlook -skip-onboarding -demo-report -uitest-mock-ai`
(DEBUG-only launch args: `-demo-fill`, `-demo-report`, `-demo-share`, `-demo-plus`, `-demo-expand`).
