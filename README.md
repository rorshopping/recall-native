# Recall Native

A native SwiftUI rebuild of Recall, intentionally separate from `rorshopping/recall-app`.

## Goals
- Native SwiftUI interface and navigation
- SwiftData persistence
- StoreKit 2 service boundary for subscriptions
- PDF import flow for on-device generation
- On-device AI service boundary ready for Apple's local model integration
- Native haptics, sheets, Dynamic Type, accessibility, and animations

No changes are made to the existing Recall repository.

## Open in Xcode
Open `RecallNative.xcodeproj` in Xcode and select an iOS Simulator/device.

The project intentionally avoids third-party UI dependencies.
