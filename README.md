# Recall Native

A native SwiftUI rebuild of Recall, intentionally separate from `rorshopping/recall-app`.

## On-device AI

Recall Native uses a two-level on-device AI strategy:

1. **Apple Foundation Models** is preferred on supported iOS 26+ devices when the system model is ready.
2. **Gemma 4 E2B through Google's LiteRT-LM** is the automatic local fallback when Apple's model is unavailable or a generation fails.

The app consumes the reusable `RecallLiteRT` Swift package from `recall-ondevice-ai`, which contains the LiteRT-LM Swift wrapper and vendored `CLiteRTLM.xcframework`.

Apple model availability is checked at runtime. The app distinguishes a model that is still preparing from Apple Intelligence being disabled or a device being ineligible, and refreshes that state when returning to the app.

The Apple model has a bounded context window, so oversized source material is routed to the Gemma fallback instead of being sent to a request that is known to exceed Apple's context limit.

The Gemma 4 E2B `.litertlm` model is about 2.59 GB, so it is not embedded in this source repository. It is downloaded on demand into the app's private Documents directory, validated against the expected model format and pinned SHA-256, then runs generation locally with no API key or inference server.

### First run

1. Generate/open the project from `project.yml` with Xcode 26+.
2. Resolve the Swift package dependency on `recall-ondevice-ai`.
3. On a supported device with Apple Foundation Models ready, generation can work without downloading Gemma.
4. Otherwise, open **Create** or **Settings → On-device AI** and download **Gemma 4** to enable the fallback.
5. After either backend is available, paste notes or import a PDF and generate cards.

The iOS Simulator deliberately does not attempt LiteRT-LM inference. Test generation on a real device.

## Architecture

- SwiftUI for the UI
- SwiftData for decks, cards and review history
- StoreKit 2 for subscriptions
- PDFKit for local PDF extraction
- Apple Foundation Models when available
- LiteRT-LM + Gemma 4 E2B as the local fallback
- No cloud inference dependency

## Licensing / attribution

The LiteRT-LM Swift layer and `CLiteRTLM.xcframework` come from the reusable `recall-ondevice-ai` integration. LiteRT-LM is Apache 2.0. Gemma weights are distributed under Google's Gemma Terms of Use. The production app must retain the applicable attribution and comply with the Gemma terms before distributing the model.

## Open in Xcode

Open `RecallNative.xcodeproj` in Xcode after regenerating it from `project.yml` if needed. The project intentionally avoids third-party UI dependencies.
