# App Store screenshots

Composed marketing screenshots — caption + framed device shot on a warm-neutral
ground. Exact App Store Connect pixel sizes; upload as-is.

| Slot | Folder | Size | Count |
|---|---|---|---|
| iPhone 6.5" | `iphone-6.5/` | 1284 × 2778 | 4 |
| iPhone 6.9" | `iphone-6.9/` | 1320 × 2868 | 4 |
| iPad 13"    | `ipad-13/`    | 2064 × 2752 | 3 |

Upload the set that matches the slot App Store Connect shows you (it currently
asks for **6.5"** — 1284 × 2778). ASC derives the remaining smaller sizes.

## Frames & captions

| # | File | Caption | Screen |
|---|---|---|---|
| 1 | `1-report` | Named reasons — never a black-box score. | The report: severity summary, "Checked on your device", stage read, plain-terms explanation |
| 2 | `2-paste`  | Paste a message. No account, nothing to sign up for. | Check screen with a reshipping-scam message pasted |
| 3 | `3-share`  | Share the findings — never the message. | The "safe copy" share sheet — plain-English flag list, message stays on device |
| 4 | `4-calm`   | Built calm, private, and account-free. | First-run screen (iPhone only) |

Order leads with the payoff (the report), then how it starts, then the privacy
share, then the promise — calm, no-account, on-device throughout, to match the
Apple-editorial North Star.

## Regenerate

Compositor: `scratchpad/compose.py` (session-local). Raw captures come from the
DEBUG launch args:

```
xcrun simctl launch <sim> com.avaresearch.secondlook \
  -skip-onboarding -demo-report 0 -uitest-mock-ai        # the report
  -skip-onboarding -demo-fill 0                           # pasted message
  -skip-onboarding -demo-report 0 -demo-share -uitest-mock-ai   # share sheet
  -onboarding-page 0                                      # first-run
```

Captured on **iPhone 17 Pro Max** and **iPad Pro 13-inch (M5)**, light appearance.
