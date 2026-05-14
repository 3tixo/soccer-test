# PitchPulse Native iOS

This folder is the separate SwiftUI version of PitchPulse. It is intentionally independent from the existing Capacitor/WebView IPA.

## What This Is

- Native SwiftUI app shell
- ESPN scoreboard service written in Swift
- Separate GitHub Actions IPA workflow
- No dependency on GitHub Pages rendering

## Build

This project uses XcodeGen so the `.xcodeproj` is generated on macOS:

```bash
brew install xcodegen
cd native-ios
xcodegen generate
xcodebuild \
  -project PitchPulseNative.xcodeproj \
  -scheme PitchPulseNative \
  -configuration Release \
  -sdk iphoneos \
  CODE_SIGNING_ALLOWED=NO \
  build
```

On Windows, use the `Build Native iOS IPA` GitHub Actions workflow.

## Notes

This is a starter native app, not a full rewrite yet. The next native features should be ported feature-by-feature from the web app:

- Match details
- Timeline
- Stats
- Lineups pitch
- Team pages
- Search
- Widgets and notifications
