# SecondLook — launch checklist

Everything left is **configuration or an external account action**, not code.
Ordered so nothing blocks on something later in the list.

## 1. Signing & build

- [ ] Set `DEVELOPMENT_TEAM` in `project.yml` (currently `""`) to the Apple
      Developer team id, then `xcodegen generate`.
- [ ] Confirm `Config/AIConfig.plist` exists on the build machine (gitignored).
      It points the app at `secondlook-ai.divine-mountain-8173.workers.dev` with
      the bootstrap token. Without it the app runs fully offline (still valid,
      just no AI phrasing / Deep AI Check).
- [ ] App icon: `SecondLook/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
      is in place. Re-check legibility at 60 px before submit.

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

## 3. App Store Connect — subscriptions

Create the group and both products (the app reads every price/period/trial from
StoreKit — do **not** hard-code):

- [ ] Subscription group **"SecondLook Plus"**.
- [ ] `com.avaresearch.secondlook.plus.monthly` — **$3.99/month**, 7-day free
      trial introductory offer.
- [ ] `com.avaresearch.secondlook.plus.yearly` — **$24.99/year**, 7-day free
      trial introductory offer.
- [ ] Display names, descriptions, localizations for each.
- [ ] Add sandbox testers; smoke-test purchase / restore / trial / cancel.

## 4. App Store Connect — app record

- [ ] **Support URL:** `https://avaj845.github.io/SecondLook/`
- [ ] **Privacy Policy URL:** `https://avaj845.github.io/SecondLook/privacy.html`
- [ ] **App Privacy questionnaire:** No data collected in the default flow.
      *Other User Content* — collected **only** when the user runs Deep AI
      Check; used for App Functionality; **not linked** to identity; **not** used
      for tracking. Matches `SecondLook/Resources/PrivacyInfo.xcprivacy`.
- [ ] **Category:** Utilities (primary), Business (secondary). Age 4+.
- [ ] Metadata: paste Name / Subtitle / Keywords / description / promo text /
      "what's new" from `AppStore/METADATA.md`.
- [ ] Screenshots (6.9"): the 6 frames listed in `AppStore/METADATA.md` — lead
      with the real report, not a welcome screen.
- [ ] **App Review notes:** paste the block at the bottom of
      `AppStore/METADATA.md` (safety/education tool, flags patterns only, Deep AI
      Check is the one opt-in network path).

## 5. After the listing is live

- [ ] Set `SecondLookLinks.appStore` in `SecondLook/Kit/ShareCard.swift` to the
      real `apps.apple.com/app/id…` URL. The share card + plain-text fallback
      switch to it automatically (they use the marketing site until then).
- [ ] Update `docs/index.html` — swap "Coming soon to the App Store" for a real
      download button.
- [ ] Wire `requestReview` at the happy moment (3rd report that found something)
      — planned in `AppStore/ASO_PLAYBOOK.md`, not yet built.

## Deferred (post-launch, tracked)

- Full App Attest per-key crypto (DeviceCheck covers the "real device" case for
  v1).
- Server-side monthly Deep AI quota mirror (keychain ledger + DO limiter cover it).
- `verifyEmployer` AI task UI (task + prompt exist, unused).
- Localization (OCR, rules, prompts, site).
