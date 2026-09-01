# Recall Native

A native SwiftUI rebuild of Recall, intentionally separate from `rorshopping/recall-app`.

## On-device AI

Recall Native uses the same on-device AI stack as the existing Recall app: **Gemma 4 E2B through Google's LiteRT-LM**. The app consumes the reusable `RecallLiteRT` Swift package from `recall-ondevice-ai`, which contains the LiteRT-LM Swift wrapper and vendored `CLiteRTLM.xcframework`.

The Gemma 4 E2B `.litertlm` model is about 2.59 GB, so it is not embedded in this source repository. On first use, the app downloads it into its private Documents directory, validates the `LITERTLM` signature and pinned SHA-256, then runs generation locally with no API key or inference server.

### First run

1. Generate/open the project from `project.yml` with Xcode 26+.
2. Resolve the Swift package dependency on `recall-ondevice-ai`.
3. On a real iPhone, open **Create** and tap **Download Gemma 4**.
4. After the model is installed, paste notes or import a PDF and generate cards.

The iOS Simulator deliberately does not attempt LiteRT-LM inference. Test generation on a real device.

## Architecture

- SwiftUI for the UI
- SwiftData for decks, cards and review history
- StoreKit 2 for subscriptions
- PDFKit for local PDF extraction
- LiteRT-LM + Gemma 4 E2B for local flashcard generation
- No cloud inference dependency

## Licensing / attribution

The LiteRT-LM Swift layer and `CLiteRTLM.xcframework` come from the reusable `recall-ondevice-ai` integration. LiteRT-LM is Apache 2.0. Gemma weights are distributed under Google's Gemma Terms of Use. The production app must retain the applicable attribution and comply with the Gemma terms before distributing the model.

## Open in Xcode

Open `RecallNative.xcodeproj` in Xcode after regenerating it from `project.yml` if needed. The project intentionally avoids third-party UI dependencies.
