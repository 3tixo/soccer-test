# PitchPulse iOS IPA Build Notes

This repo includes a Capacitor iOS wrapper that loads:

`https://3tixo.github.io/soccer-test/`

That means the IPA is only the native shell. When you push updates to the hosted site, the app should load the updated site without rebuilding the IPA, unless iOS/WebView caching gets in the way.

## Files

- `capacitor.config.json` - native wrapper config
- `www/index.html` - local fallback page required by Capacitor
- `ios/` - generated Xcode project

## Windows

Windows can install dependencies and generate/sync the Capacitor iOS project, but it cannot run Xcode locally.

The repo includes a GitHub Actions workflow that uses a macOS runner to build an unsigned IPA:

`.github/workflows/ios-ipa.yml`

Useful commands:

```powershell
npm install
npx cap sync ios
```

Then:

1. Commit and push the repo to GitHub.
2. Open the repo on GitHub.
3. Go to **Actions**.
4. Run **Build iOS IPA**.
5. Download the `PitchPulse-unsigned-ipa` artifact.
6. Try installing that IPA with SideStore.

SideStore normally signs apps during sideloading with your Apple Account, so an unsigned IPA artifact is usually the right thing to try. If SideStore rejects it, you will need a signed IPA from Xcode or a cloud iOS signing service.

## Mac / Xcode IPA Build

On a Mac:

```bash
npm install
npx cap sync ios
npx cap open ios
```

In Xcode:

1. Select the `App` target.
2. Set your Apple Team under **Signing & Capabilities**.
3. Confirm the bundle identifier, currently `com.tixo.pitchpulse`.
4. Choose **Any iOS Device** or your connected iPhone.
5. Use **Product > Archive**.
6. Export a signed app / IPA.

## SideStore Install

Once you have a signed `.ipa`, install it with SideStore:

1. Put the IPA in Files on your iPhone.
2. Open SideStore.
3. Tap `+`.
4. Pick the IPA.
5. Keep LocalDevVPN enabled when installing or refreshing.

With a free Apple account, sideloaded apps usually need refreshing every 7 days.

## Widget Extension

The iOS project includes a native `PitchPulseWidgetExtension` WidgetKit target. It shows a small/medium Home Screen widget with a Premier League match from ESPN.

When installing with SideStore, keep app extensions enabled if SideStore asks. If the widget does not appear immediately, open the app once after installing, then long-press the Home Screen and add the PitchPulse widget.

iOS controls how often widgets refresh, so this widget is not a real-time live ticker.
