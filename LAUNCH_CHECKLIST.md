# SecondLook — launch checklist

Everything left is **configuration or an external account action**, not code.
Ordered so nothing blocks on something later in the list. The unsigned archive
builds clean (`ARCHIVE SUCCEEDED` with `CODE_SIGNING_ALLOWED=NO`) — only signing
+ the App Store Connect records remain.

Version is `1.0` (build `2`). `ITSAppUsesNonExemptEncryption` is declared `false`
(HTTPS/TLS only) so no export-compliance prompt per upload. Privacy manifests
ship in the app and both extensions.

The app now has **three** targets: `SecondLook`, `ShareExtension`, and
`SecondLookWidgets` (Control Center control + Home/Lock Screen widget), all
sharing the App Group **`group.com.avaresearch.secondlook`**.

## 0. Capabilities (one-time, in the Apple Developer portal or via Xcode)

- [ ] **App Groups** — with automatic signing + `-allowProvisioningUpdates`,
      Xcode creates `group.com.avaresearch.secondlook` and adds it to the
      `com.avaresearch.secondlook`, `.share`, and `.widgets` App IDs on first
      archive. If you sign manually, add the App Groups capability to all three
      App IDs and select that group.
- [ ] Register the widget bundle id **`com.avaresearch.secondlook.widgets`** as
      an App ID (automatic signing does this too).

## 1. Get to TestFlight

Needs: paid Apple Developer membership, Xcode signed in to that Apple ID.

```sh
cd ~/Documents/SecondLook

# 1. Register the app in App Store Connect first (see §4) so the bundle id
#    com.avaresearch.secondlook exists.

# 2. Confirm the AI backend config is present (gitignored, must be local):
ls Config/AIConfig.plist    # BaseURL + bootstrap token — without it the app
                            # runs fully offline (valid, just no AI phrasing).

# 3. Archive (TEAMID = your 10-char Apple Developer Team ID):
xcodegen generate
xcodebuild -project SecondLook.xcodeproj -scheme SecondLook \
  -destination 'generic/platform=iOS' -archivePath build/SecondLook.xcarchive \
  archive \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=TEAMID

# 4. Export + upload:
xcodebuild -exportArchive -archivePath build/SecondLook.xcarchive \
  -exportPath build/export -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates
xcrun altool --upload-app -f build/export/SecondLook.ipa -t ios \
  --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>       # App Store Connect API key
```

`ExportOptions.plist` (create once, gitignore it):
```xml
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>TEAMID</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><true/>
</dict></plist>
```

Or just: Xcode → **Product → Archive** → **Distribute App → App Store Connect →
Upload**. Same result, handles signing interactively.

- [ ] After upload: App Store Connect → TestFlight → the build finishes
      processing (~10–30 min) → add **internal testers** (no review needed).
- [ ] For **external** testers: fill "What to Test" + the beta description, then
      submit for **Beta App Review** (usually < 24 h, lighter than full review).
- [ ] App icon legibility: re-check `AppIcon-1024.png` at 60 px before submit.

## 2. Backend — turn on device attestation

The Durable Object rate limiter is already live. DeviceCheck enforcement is one
key away — no app update needed.

- [ ] Apple Developer → Certificates, Identifiers & Profiles → **Keys** → **+** →
      enable **DeviceCheck** → download the `.p8`.
- [ ] ```sh
      cd backend
      npx wrangler secret put DEVICECHECK_KEY      # full .p8 contents (PEM)
      npx wrangler secret put DEVICECHECK_KEY_ID   # the 10-char key id
      npx wrangler secret put APPLE_TEAM_ID        # 10-char team id
      ```
- [ ] Verify: register from a **real device** succeeds; the worker log
      (`npx wrangler tail`) no longer prints "DeviceCheck not configured".
- [ ] Rotate `SECONDLOOK_CLIENT_TOKEN` and `INSTALL_TOKEN_SECRET` if either was
      ever pasted anywhere outside `wrangler secret put`.

## 3. App Store Connect — subscriptions (P0 — paywall is dead without this)

App Store Connect → your app → **Monetization → Subscriptions**. The app reads
every price / period / trial from StoreKit at runtime — nothing is hard-coded,
so ASC is the source of truth. Match `SecondLook.storekit` exactly:

- [ ] **Create a Subscription Group.** Reference name: `SecondLook Plus`.
      Localized group display name: `SecondLook Plus`.
- [ ] **Product 1 — Monthly**
  - Reference Name: `SecondLook Plus Monthly`
  - Product ID: `com.avaresearch.secondlook.plus.monthly`  *(must match exactly)*
  - Duration: **1 Month**
  - Price: **USD 3.99** (Tier that shows $3.99 in the US)
  - Localization (en-US): Display Name `SecondLook Plus`, Description
    `Track whole conversations, the full breakdown on every flag, and 20 Deep AI Checks a month.`
  - **Introductory Offer:** New Subscribers · **Free** · **1 Week**
- [ ] **Product 2 — Yearly**
  - Reference Name: `SecondLook Plus Yearly`
  - Product ID: `com.avaresearch.secondlook.plus.yearly`
  - Duration: **1 Year**
  - Price: **USD 24.99**
  - Localization (en-US): Display Name `SecondLook Plus (Yearly)`, Description
    `Everything in Plus, best value — about $2.08/month.`
  - **Introductory Offer:** New Subscribers · **Free** · **1 Week**
- [ ] Add a **Subscription Group localization** and, for the first submission,
      attach a screenshot of the paywall (ASC requires one per group).
- [ ] **Paid Applications agreement** must be Active (Business → Agreements).
- [ ] Create a **Sandbox tester** (Users and Access → Sandbox) and smoke-test
      on a device: purchase → Plus unlocks, force-quit → still Plus, Settings →
      cancel → back to Free, restore → Plus.
- [ ] The two products must be **submitted with the first app version** (attach
      them to the version in the "In-App Purchases and Subscriptions" section)
      or the paywall shows "Plans couldn't be loaded" in review.

## 4. App Store Connect — app record

- [ ] **Support URL:** `https://avaj845.github.io/SecondLook/`
- [ ] **Privacy Policy URL:** `https://avaj845.github.io/SecondLook/privacy.html`
- [ ] **App Privacy questionnaire:** No data collected in the default flow.
      *Other User Content* — collected **only** when the user runs Deep AI
      Check; used for App Functionality; **not linked** to identity; **not** used
      for tracking. Matches `SecondLook/Resources/PrivacyInfo.xcprivacy`.
- [ ] **Category:** Utilities (primary), Business (secondary). Age 4+.
- [ ] **Notifications:** the app schedules *local* notifications only (a weekly
      practice nudge + a quiet-thread note), requested as **provisional** so no
      permission prompt is shown. Nothing to declare, but the review notes can
      mention it: *"Reminders are local notifications, opt-out in About, no push
      server."* Users toggle them off under About → Reminders.
- [ ] Metadata: paste Name / Subtitle / Keywords / description / promo text /
      "what's new" from `AppStore/METADATA.md`.
- [ ] **Screenshots (6.9"):** ready in `AppStore/screenshots/` — native
      1320 × 2868, upload to the 6.9" slot and ASC derives the rest. Captions in
      that folder's README. Add 1–2 device-captured frames of the Plus features
      (deeper report, conversation threads) before final submission.
- [ ] **App Review notes:** paste the block at the bottom of
      `AppStore/METADATA.md` (safety/education tool, flags patterns only, Deep AI
      Check is the one opt-in network path). Add: *"SecondLook Plus is submitted
      with this version; sign in is not required for any feature."*

## 5. After the listing is live

- [ ] Set `SecondLookLinks.appStore` in `SecondLook/Kit/ShareCard.swift` to the
      real `apps.apple.com/app/id…` URL. The share card + plain-text fallback
      switch to it automatically (they use the marketing site until then).
- [ ] Update `docs/index.html` — swap "Coming soon to the App Store" for a real
      download button.
- [x] `requestReview` at the happy moment — built (`Support/ReviewPrompt.swift`;
      fires on the 3rd and 8th report that found something, once per version).

## Deferred (post-launch, tracked)

- Full App Attest per-key crypto (DeviceCheck covers the "real device" case for
  v1).
- Server-side monthly Deep AI quota mirror (keychain ledger + DO limiter cover it).
- `verifyEmployer` AI task UI (task + prompt exist, unused).
- Localization (OCR, rules, prompts, site).
