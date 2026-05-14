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

Current native features:

- ESPN scoreboard
- League switching
- Team/match/news search
- Matches tab
- Standings tab
- News tab
- Match detail sheet
- Match timeline when ESPN summary data exists
- Match stats when ESPN box score data exists
- Native kickoff notification scheduling
- Previous / next / today date controls
- Team detail sheet from standings
- Decimal odds display in match details when ESPN returns odds

Still to port from the web app:

- Native lineup pitch
- Native WidgetKit target wired into this new native app
