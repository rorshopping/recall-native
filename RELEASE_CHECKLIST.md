# Recall Native — App Store Release Checklist

Generated: 2026-09-02
Bundle ID: `com.recalllabs.recallnative`
Team: `AGYVQ59A5S`
Deployment target: iOS 18.0
Marketing version: 0.1.0
Build number: 1

---

## ✅ What was prepared (local, NOT submitted)

| Artifact | Path | Size | Notes |
|---|---|---|---|
| Xcode archive | `.build/RecallNative.xcarchive` | 45 MB (expanded .app) | Signed with Apple Distribution cert |
| Signed IPA | `.build/export/RecallNative.ipa` | 15.4 MB | arm64, ready for upload |
| ExportOptions.plist | `.build/ExportOptions.plist` | — | References UUID of App Store profile |
| App Store provisioning profile | `~/Library/Developer/Xcode/UserData/Provisioning Profiles/fcc16d70-41d3-4fb0-bd55-0949f5b8afc6.mobileprovision` | 13 KB | Includes iCloud KVS entitlement |

### Build verification

- ✅ `xcodebuild … archive` → **ARCHIVE SUCCEEDED**
- ✅ `xcodebuild -exportArchive` → **EXPORT SUCCEEDED**
- ✅ Archive `Info.plist` `SigningIdentity` = `Apple Distribution: Richard Otto Raoul Bäcker (AGYVQ59A5S)`
- ✅ IPA bundle: arm64, CFBundleShortVersionString=`0.1.0`, CFBundleVersion=`1`, MinimumOSVersion=`18.0`
- ✅ Codesign chain: `Apple Distribution: Richard Otto Raoul Bäcker (AGYVQ59A5S)` → `Apple Worldwide Developer Relations Certification Authority` → `Apple Root CA`
- ✅ Embedded entitlements include `com.apple.developer.ubiquity-kvstore-identifier` = `AGYVQ59A5S.com.recalllabs.recallnative`
- ✅ `get-task-allow = false` (correct for App Store; would be `true` for development)
- ✅ App icon: indigo `Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`, auto-generated all sizes
- ✅ `UILaunchScreen_Generation = YES` set in `project.yml` (iOS 26 letterbox fix)
- ✅ Embedded framework: `CLiteRTLM.framework` (RecallLiteRT SPM dep, version 0.1.4)
- ✅ No debug-only code, no example.com URLs, no stub products in shipped binary

### Pre-release warnings (not blocking, upstream code)

These existed on `origin/main` and don't fail the build but you may want to fix them before first public release:

- `AdvancedAIService.swift:48,52` — `??` on non-optional `Any` value (dead branch)
- `HapticsService.swift:8-11` — calls to `UIImpactFeedbackGenerator` and friends from non-main-actor context (Swift 6 concurrency strictness, currently warning-level)
- `RecallNative` — "All interface orientations must be supported unless the app requires full screen" — set `INFOPLIST_KEY_UIRequiresFullScreen` or declare supported orientations explicitly

---

## 🟡 NOT prepared (intentionally — out of scope this round)

These are the App Store Connect-side steps that need to happen *before* you can submit. The local build is ready; the rest is metadata + ASC plumbing.

### App Store Connect app record

There is **no app record** on ASC for `com.recalllabs.recallnative` yet. ASC's API cannot create app records — you need the web portal OR `fastlane spaceauth`. To create it:

1. Open https://appstoreconnect.apple.com → My Apps → `+` → New App
2. Platform: iOS
3. Name: `Recall Native`
4. Primary language: English
5. Bundle ID: `com.recalllabs.recallnative`
6. SKU: `recallnative-001` (your choice; unique per app)
7. User access: Full access

Alternatively via `fastlane spaceauth` — see `ios-asc-pipeline` skill (one-time 2FA prompt required; everything else is automated).

### In-App Purchase / Subscription

The app only has **one** paid product in code:

| Product ID | Type | Price label | Source |
|---|---|---|---|
| `recall_yearly` | Auto-renewing subscription | 39,99 € / year | `SubscriptionService.swift:11`, `EntitlementRules.swift:7-8` |

To configure on ASC (after app record exists):

1. ASC → My Apps → Recall Native → Subscriptions → `+`
2. Reference name: `Recall Yearly`
3. Product ID: `recall_yearly`
4. Subscription group: create new `Recall` group
5. Duration: 1 Year
6. Subscription price: 39,99 € (or set up pricing matrix)
7. Localizations: English — display name "Recall Yearly", description "Unlock unlimited decks and cards."
8. Review screenshot: required if no app-level screenshots include the paywall
9. App Store review info: screenshot for review, demo account (sandbox tester)

### Listing metadata

| Field | Value |
|---|---|
| Subtitle | (optional, ≤30 chars) |
| Promotional text | (rotating, ≤170 chars) |
| Description | (≤4000 chars) |
| Keywords | `flashcards,spaced,repetition,study,recall,memory` (≤100 chars) |
| Support URL | `https://rorshopping.github/recall-native/support` |
| Marketing URL | (optional) |
| Privacy Policy URL | `https://rorshopping.github/recall-native/privacy` |
| Categories | Primary: Education; Secondary: Productivity |
| Content rights | (only if you own all content) |
| Age rating | Complete questionnaire; expect 4+ (no objectionable content) |
| Copyright | `© 2026 Richard Bäcker` |

### Screenshots (intentionally skipped)

Required for App Store submission but were scoped out this round:

- 6.7" iPhone (iPhone 15 Pro Max, 1290×2796) — **REQUIRED** for iPhone 15 Pro Max display
- 6.5" iPhone (iPhone 11 Pro Max, 1242×2688) — backward-compat
- 5.5" iPhone (iPhone 8 Plus, 1242×2208) — backward-compat
- 12.9" iPad (3rd gen, 2048×2732) — only if iPad is supported (deployment target is iOS 18, not iPadOS-specific — likely still needed)

Each size: 1–10 screenshots. The skill `ios-sim-testing` has a recipe (`screenshot-batch.py`) to capture these once screenshots are in scope.

### App Privacy

Required questionnaire covering:
- Contact Info (none collected)
- Financial Info (none; StoreKit only — Apple handles payment)
- Health & Fitness (none)
- Location (none)
- Sensitive Info (none)
- Contacts (none)
- User Content (card contents stored locally + iCloud KVS opt-in)
- Browsing History (none)
- Search History (none)
- Identifiers (none; no analytics SDK)
- Usage Data (none)
- Diagnostics (none)
- Purchases (yes — StoreKit reports purchase history to Apple)

For iCloud KVS specifically: data is synced via `NSUbiquitousKeyValueStore` to the user's iCloud. Mark "User Content" as "Data is synced via iCloud" if applicable.

### Age rating

Complete the standard questionnaire. Expect:
- Cartoon/ Fantasy Violence: No
- Realistic Violence: No
- Sexual Content: No
- Profanity/Crude Humor: No
- Alcohol/ Tobacco/ Drugs: No
- Medical/ Treatment Info: No
- Gambling: No
- Horror/ Fear: No
- Mature/ Suggestive: No
- User-Generated Content: No (no sharing between users)
Expected rating: **4+**.

### Export compliance

Standard App Store submission asks:
- Is your app designed to use cryptography? **Yes** (HTTPS connections for AI model download)
- Does your app qualify for any exemptions? **Yes** — uses only standard HTTPS/TLS, exempt under category 5 part 2 note 4

---

## 🚀 Submission commands (when ready)

1. Upload IPA to ASC:
   ```bash
   cd "/Users/richardbaecker/Documents/projects/recall-native"
   mkdir -p ~/.appstoreconnect/private_keys/
   cp ~/.secrets/AuthKey_BP3N265886.p8 ~/.appstoreconnect/private_keys/
   xcrun altool --upload-app \
     -f .build/export/RecallNative.ipa \
     --apiIssuer 0afd4489-463e-4b94-b7fa-24d26ffb7f2f \
     --apiKey BP3N265886
   ```

2. After upload completes (build becomes `VALID` state), attach to a new version in ASC UI and submit for review.

---

## 🐛 Known build-time warnings worth fixing before v1.1

These don't block submission but will become errors in future Swift versions and should be addressed eventually:

1. `AdvancedAIService.swift:48,52` — `??` after `if let`/cast where the value is already non-optional. Replace `x ?? y` with just `x`.
2. `HapticsService.swift` — wrap haptic generators in `@MainActor` or call from MainActor.run.
3. `INFOPLIST_KEY_UIRequiresFullScreen` — set explicitly or declare supported orientations to silence the warning and ensure iPad split-view behavior is correct.