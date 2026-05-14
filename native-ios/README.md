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
- Native lineup pitch with formation rows, player numbers, position labels, ratings, and bench lists
- League switching uses ESPN's default match day for each league until the user manually picks a date
- Native WidgetKit target embedded in the SwiftUI app
- Persistent favorite teams and favorite-match filtering
- Team pages fetch ESPN profile, schedule, and team news
- Match details use segmented tabs for Summary, Stats, Lineups, Odds, and News

Still to port from the web app:

- Widget favorite-team configuration
- Favorite-only notification scheduling
