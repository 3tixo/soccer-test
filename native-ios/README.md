# PitchPulse Native iOS

This folder is the separate SwiftUI version of PitchPulse. It is intentionally independent from the existing Capacitor/WebView IPA.

## What This Is

- Native SwiftUI app shell
- SofaScore service written in Swift
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

SofaScore endpoints are private/undocumented. The app sends browser-like request headers, but native `URLSession` can still be blocked with `403`; if that happens, put SofaScore behind a small backend/proxy and let the iOS app call your normalized API.

Current native features:

- SofaScore match schedule
- League switching
- Team/match/news search
- Matches tab
- Standings tab
- News tab
- Match detail sheet
- Match timeline when SofaScore incidents exist
- Match stats when SofaScore statistics exist
- Native kickoff notification scheduling
- Previous / next / today date controls
- Team detail sheet from standings
- Decimal odds display in match details when SofaScore returns odds
- Native lineup pitch with formation rows, player numbers, position labels, ratings, and bench lists
- League switching uses SofaScore unique tournament IDs
- Native WidgetKit target embedded in the SwiftUI app
- Configurable widget: edit the widget on iOS to choose league and Live first / Next match / Latest result
- Persistent favorite teams and favorite-match filtering
- Team pages fetch SofaScore profile, schedule, and media
- Match details use segmented tabs for Summary, Stats, Lineups, Odds, and News

Still to port from the web app:

- Widget favorite-team configuration through an App Group or AppIntent entity picker
- Favorite-only notification scheduling
