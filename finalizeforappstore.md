# Finalize for App Store — Recall Native

> Source of truth for what is **done**, what is **deferred**, and what remains before submission.
> Last updated: 2026-09-02

**Bundle ID:** `com.recalllabs.recallnative`  
**Team:** `AGYVQ59A5S`  
**ASC App ID:** `6807825754` — *Recall Native*  
**Version / Build:** `0.1.0` / `1` (see `project.yml` `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`)  
**Deployment target:** iOS 18.0  
**XcodeGen:** `project.yml` → `RecallNative.xcodeproj` (generated, not committed)  
**ASC API key:** `BP3N265886` (`~/.secrets/AuthKey_BP3N265886.p8`, issuer `0afd4489-463e-4b94-b7fa-24d26ffb7f2f`)

---

## 1) Done

### 1.1 App record (via `fastlane produce`, web session required)

- Created via `fastlane produce create -u ror1994@gmail.com -a com.recalllabs.recallnative -q "Recall Native" -y recall-native-001 -m en-US --team_id AGYVQ59A5S`
- `bundleId` already existed in Developer Portal (`com.recalllabs.recallnative` / `X3PU6QU2Q3`), ASC app record was new
- Cookie: `~/.fastlane/spaceship/ror1994@gmail.com/cookie` (fresh 2026-09-02 14:35, 8 cookies)
- Verification: `GET /v1/apps/6807825754` returns `name: Recall Native`, `bundleId: com.recalllabs.recallnative`, `sku: recall-native-001`, `primaryLocale: en-US`, `contentRightsDeclaration: DOES_NOT_USE_THIRD_PARTY_CONTENT` (patched), `streamlinedPurchasingEnabled: true`

### 1.2 Provisioning

- **Development:** `IOS_APP_DEVELOPMENT` profile for `X3PU6QU2Q3` + device `75TCN9H9S8` (iPhone 16 richi) via ASC API — used earlier for on-device builds
- **App Store:** `IOS_APP_STORE` profile `recall-native-appstore` **fcc16d70-41d3-4fb0-bd55-0949f5b8afc6** (expires 2027-08-21), cert `GLK9354FC7` (Apple Distribution), entitlements include `com.apple.developer.ubiquity-kvstore-identifier = AGYVQ59A5S.*`, `get-task-allow: false`, installed to `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`
- iCloud KVS capability enabled on App ID `X3PU6QU2Q3` (`ICLOUD` / `XCODE_6`) — required for `RecallNative.entitlements`

### 1.3 Subscription — `recall_native_yearly` (new native-only product)

- **Decision:** `recall_yearly` already exists under Expo app `com.recalllabs.recall` (sub `6807354927`, `READY_TO_SUBMIT`, shared globally unique productId). Created separate native product **`recall_native_yearly`** to avoid collision. User confirmed `recall_native_yearly`.
- Group: `Recall` **22353875** (referenceName `Recall`)
- Group localization: `en-US` / `Recall` (`d7bfd69a-b493-4c02-af1d-7c1fa12ef8ba`)
- Subscription: **6807862098** `Recall Native Yearly`, `productId: recall_native_yearly`, `ONE_YEAR`, `familySharable: false`, `groupLevel: 1`
- Localization: `en-US` `Recall Native Yearly` / `Unlock unlimited decks and cards.` (`9f64ef58-afb1-4706-a4ce-4f0b52354a83`)
- Price: USA anchor `p=10277` (`39.99` USD, `proceeds 33.99`) — `eyJzIjoiNjgwNzg2MjA5OCIsInQiOiJVU0EiLCJwIjoiMTAyNzcifQ`, patched via `PATCH /v1/subscriptions/6807862098` with `subscriptionPrices` inline (`${p0}`), then fanned to **174 territories** via `GET /v1/subscriptionPricePoints/{usa_pp}/equalizations` + chunked `PATCH` (60 per call) using `asc_sub_pricing_fix.py:fanout_prices`
- Availability: `subscriptionAvailabilities` **6807862098**, `availableInNewTerritories: true`, all **175 territories** (POST `/v1/subscriptionAvailabilities` — note: wrapped body bug in helper fixed manually)
- State: `MISSING_METADATA` — only **review screenshot** missing (deferred per instruction "dont do screenshots yet")

### 1.4 App metadata (ASC, via API + `spaceauth` session)

| Item | Endpoint / action | Value |
|------|-------------------|-------|
| `contentRightsDeclaration` | `PATCH /v1/apps/6807825754` | `DOES_NOT_USE_THIRD_PARTY_CONTENT` |
| `appPriceSchedule` | `POST /v1/appPriceSchedules` | Free — USA `p=10000` (`0.0`), `baseTerritory: USA`, `manualPrices: [${p1}]` → id `6807825754` |
| `appStoreReviewDetails` | `POST /v1/appStoreReviewDetails` | `d93335c4-4791-42f1-9de8-e2d17c289d32` / Richard Bäcker / `+49 30 12345678` / `ror1994@gmail.com` / `demoAccountRequired: false` |
| `appInfoLocalization` en-US `f476a3a7-8a93-4eaa-a19b-a86190a89c4f` | `PATCH /v1/appInfoLocalizations/...` | `name: Recall Native`, `subtitle: Flashcards & Spaced Repetition`, `privacyPolicyUrl: https://rorshopping.github.io/recall-native/privacy` |
| `appStoreVersionLocalization` en-US `63f7394f-94fb-4ee6-a94c-5d5f1e4b8f3a` | `PATCH /v1/appStoreVersionLocalizations/...` | `description`, `keywords: flashcards,spaced,repetition,study,recall,memory,anki`, `promotionalText: Study smarter with spaced repetition.`, `supportUrl: https://rorshopping.github.io/recall-native/support`, `marketingUrl: https://rorshopping.github.io/recall-native` |
| `primaryCategory` | `PATCH /v1/appInfos/3e5896ff-9f97-4364-bdb0-9f4e6ae0701b` → `EDUCATION` | verified via `GET /primaryCategory` |
| `copyright` | `PATCH /v1/appStoreVersions/6b39ee91-a28b-4cca-9bf6-b3a5c016dfdc` | `© 2026 Richard Bäcker` |
| Privacy | `fastlane run upload_app_privacy_details_to_app_store` | `DATA_NOT_COLLECTED` — published (`App data usage is now published`) |

Version / appInfos:
- `appStoreVersion` **6b39ee91-a28b-4cca-9bf6-b3a5c016dfdc** — `IOS`, `1.0`, `PREPARE_FOR_SUBMISSION`, `releaseType: AFTER_APPROVAL`
- `appInfo` **3e5896ff-9f97-4364-bdb0-9f4e6ae0701b** — `PREPARE_FOR_SUBMISSION`

### 1.5 Code

- `RecallNative/Services/SubscriptionService.swift:11` — `productIDs = ["recall_native_yearly"]` (was `recall_yearly`)
- `RecallNative/Services/EntitlementRules.swift:7` — `yearlyProductID = "recall_native_yearly"`
- Committed `7b2cdcc` *Use recall_native_yearly product ID* and pushed to `origin/main` (rebased onto `a0c5c4a`)

### 1.6 Build artifacts (prior run, now stale — to be rebuilt)

- `.build/RecallNative.xcarchive` (45 MB app, `Apple Distribution: Richard Otto Raoul Bäcker (AGYVQ59A5S)`, arm64, `0.1.0`/`1`, `MinimumOSVersion 18.0`, `UILaunchScreen` present, `CLiteRTLM.framework` embedded, `Assets.car` 103 KB, `AppIcon60x60@2x.png` + `AppIcon76x76@2x~ipad.png` auto-generated)
- `.build/export/RecallNative.ipa` (15.4 MB) + `.build/ExportOptions.plist` (`manual`, `fcc16d70-…`)
- `RecallNative/Assets.xcassets` — indigo background, 3-card stack + yellow circular-arrow badge (single 1024×1024, `Contents.json` Single Size)
- **Stale:** upstream landed `BackupService.swift` / `LegacyBackupService.swift` / tests after the last archive — next archive must include them (user: "we will build again later, still implementing new stuff")

---

## 2) Deferred (explicitly skipped)

- **App Store screenshots** — `APP_IPHONE_67` etc. (6.7" 1290×2796 required). User: "dont do screenshots yet". Skill `ios-sim-testing` recipe `screenshot-batch.py` + `sips -z 2796 1290` resample when re-enabled.
- **Subscription review screenshot** — `POST /v1/subscriptionAppStoreReviewScreenshots` → PUT via `uploadOperations` → `PATCH uploaded:true` + `md5`. Blocks sub state `MISSING_METADATA → READY_TO_SUBMIT`. Orphan recovery via `GET .../relationships/appStoreReviewScreenshot` + `DELETE`.
- **Build upload** — `xcrun altool --upload-app -f .build/export/RecallNative.ipa --apiIssuer 0afd4489-463e-4b94-b7fa-24d26ffb7f2f --apiKey BP3N265886` requires a non-stale archive; deferred.

---

## 3) Still to do before submission

1. **Re-archive + export + validate** — `xcodegen generate`, `xcodebuild -project … -scheme RecallNative -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -archivePath .build/RecallNative.xcarchive ... CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Apple Distribution" PROVISIONING_PROFILE_SPECIFIER=fcc16d70-41d3-4fb0-bd55-0949f5b8afc6 archive`, then `-exportArchive` with `.build/ExportOptions.plist`. Verify `ApplicationProperties.SigningIdentity`, `Assets.car`, entitlements, and `strings` grep for debug URLs/productIds.

2. **Screenshots** — when re-enabled:
   - Capture via `ios-sim-testing` (`capture-app.sh` / `capture-steps.py`)
   - Sets: `POST /v1/appScreenshotSets` with `screenshotDisplayType: APP_IPHONE_67` (attribute, not relationship) + `appStoreVersionLocalization`, then `POST /v1/appScreenshots` + PUT + `PATCH uploaded+md5`, verify `state: UPLOAD_COMPLETE`
   - Dimension fix if needed: `sips -z …` + RGBA→RGB flatten

3. **Subscription screenshot** — generate `sb_shot.png` (`/tmp/.../sb_shot.png`) containing paywall, then `asc_sub_pricing_fix.py` logic (`ensure_screenshot`) or `scripts/capture-app.sh` for the review image.

4. **Pre-flight re-check** (the 5 blockers):
   - `appStoreReviewDetails` ✓ done
   - Privacy `DATA_NOT_COLLECTED` published ✓ done
   - `appPriceSchedule` Free ✓ done
   - `contentRightsDeclaration` ✓ done
   - Screenshots dimension-strict — pending (2)

5. **Upload** — `xcrun altool --upload-app` (fastlane pilot JSON-form broken on this Mac: `OpenSSL::PKey::PKeyError`). Use raw `.p8` at `~/.appstoreconnect/private_keys/AuthKey_BP3N265886.p8`.

6. **Attach build to version** — after build `VALID`, `PATCH /v1/appStoreVersions/{id}` with `relationships.build: {data: {type: builds, id: …}}` (singular, not array). Then `whatsNew` becomes editable.

7. **Submit for review** — `App Manager` API key cannot `POST /v1/appStoreVersionSubmissions` (403). Need web session: `fastlane deliver submit_build -u ror1994@gmail.com` after `spaceauth-window.sh`, or re-issue API key as **Admin**.

8. **Age rating** — questionnaire via `appInfos` / `ageRatingDeclaration` (expect 4+: no cartoon/realistic violence, sexual, profanity, alcohol, medical, gambling, horror, UGC).

9. **Export compliance** — `ITSAppUsesNonExemptEncryption` Q: uses HTTPS for AI model download → exempt (standard TLS).

---

## 4) References

- `RELEASE_CHECKLIST.md` — auto-generated local artifacts + pre-release Swift warnings
- `ios-asc-pipeline` skill — API gotchas (filter[identifier] unreliable, 500s, 409 duplicates, `aud: appstoreconnect-v1`, `familyShareable` not creatable, `availableInAllTerritories` invalid, territory vs country `US`/`USA` normalization, `subscriptionPricePoint` base64, equalizations paging)
- `ios-build-pipeline` skill — `ExportOptions.plist` out of `.build/export`, `ProvisioningStyle = Manual` trap, `UILaunchScreen_Generation: YES`, App Store profile mint with `IOS_APP_STORE` + Distribution cert
- `~/Documents/projects/ios-launch-kit` — `scripts/spaceauth-window.sh`, `asc_testflight.py`, `asc_sub_pricing_fix.py`, `AGENTS.md`, `docs/APPLE_APP_STORE_GUIDE.md`
- Portfolio reference: `com.recalllabs.recall` / `6804064805` / group `Recall Access` `22350682` / sub `recall_yearly` `6807354927` `READY_TO_SUBMIT` (39.99 via `p=10277`)
- Key paths: `scripts/asc_testflight: req` handles JWT with `aud` + clock skew; `BUNDLE_PATH=vendor/bundle` fixes Homebrew fastlane `digest-crc` gem miss

---

## 5) Ids at a glance

```
Team: AGYVQ59A5S (rorschopping, ror1994@gmail.com)
App: 6807825754 (com.recalllabs.recallnative, Recall Native, en-US, sku recall-native-001)
  appInfo: 3e5896ff-9f97-4364-bdb0-9f4e6ae0701b
    appInfoLocalization: f476a3a7-8a93-4eaa-a19b-a86190a89c4f (en-US)
  appStoreVersion: 6b39ee91-a28b-4cca-9bf6-b3a5c016dfdc (1.0, PREPARE_FOR_SUBMISSION, IOS)
    appStoreVersionLocalization: 63f7394f-94fb-4ee6-a94c-5d5f1e4b8f3a (en-US)
    appStoreReviewDetail: d93335c4-4791-42f1-9de8-e2d17c289d32
  appPriceSchedule: 6807825754 (Free, USA p=10000)
SubscriptionGroup: 22353875 (Recall)
  groupLocalization: d7bfd69a-b493-4c02-af1d-7c1fa12ef8ba (en-US Recall)
  Subscription: 6807862098 (recall_native_yearly, ONE_YEAR, MISSING_METADATA — needs screenshot)
    localization: 9f64ef58-afb1-4706-a4ce-4f0b52354a83 (en-US Recall Native Yearly)
    subscriptionAvailabilities: 6807862098 (availableInNewTerritories true, 175 territories)
BundleId: X3PU6QU2Q3 (com.recalllabs.recallnative, ICLOUD XCODE_6)
Profile App Store: fcc16d70-41d3-4fb0-bd55-0949f5b8afc6 (recall-native-appstore, IOS_APP_STORE, GLK9354FC7, 2027-08-21)
Cert Distribution: GLK9354FC7 (Apple Distribution)
```

Upload command (when ready):

```bash
mkdir -p ~/.appstoreconnect/private_keys/
cp ~/.secrets/AuthKey_BP3N265886.p8 ~/.appstoreconnect/private_keys/
xcrun altool --upload-app \
  -f /Users/richardbaecker/Documents/projects/recall-native/.build/export/RecallNative.ipa \
  --apiIssuer 0afd4489-463e-4b94-b7fa-24d26ffb7f2f \
  --apiKey BP3N265886
```
