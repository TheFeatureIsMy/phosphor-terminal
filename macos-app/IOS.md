# iOS App (AlphaLoopIOS)

Shared sources from `AlphaLoop/` (Models, Services, ViewModels, DesignSystem,
Localization, State) are compiled directly into the iOS target. macOS-only
files are excluded in `project.yml`.

## Build

```bash
# XcodeGen is required to regenerate the project (the .xcodeproj is ignored).
xcodegen generate --spec project.yml

xcodebuild -project AlphaLoopIOS.xcodeproj \
  -scheme AlphaLoopIOS \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .iosbuild \
  CODE_SIGNING_ALLOWED=NO build
```

The simulator talks to the Mac host via `http://127.0.0.1:8000` (Info.plist
`APIBaseURL`). A device build must point this at the remote server.

## Current scope

- Login (`/auth/login`) with the shared `AuthState` + `LiveNetworkClient`;
- Session restore from iOS Keychain at launch;
- Dashboard: account equity, runtime counts, risk state, open positions;
- Strategies: list → versions → run a 90-day backtest → poll command status → show metrics;
- Execution: orders + positions, per-row cancel / market close and batch cancel-all / close-all, all with confirmation;
- Risk: overview + rules, persistable “block new entries” / unblock with confirmation;
- Canvas: read-only WKWebView using the same `canvas-web` bundle, DSL injected via the JS bridge;
- Settings: server base URL (restart to apply), language toggle, logout.
- Pull to refresh; logout.

## Known gaps

- macOS still uses in-memory tokens (login is bypassed there);
- No push notifications, no offline cache;
- iOS deployment target is 26.0 pending a product decision;
- No simulator runtime is installed on this machine, so only compile verification was possible.

## Simulator E2E (2026-11-17)

The app was installed and launched on an iOS 27.2 simulator against a local
backend. For test automation only, the DEBUG build accepts:

```bash
xcrun simctl launch booted com.alphaloop.ios \
  -autoLoginEmail ios@example.com -autoLoginPassword secret123
```

This path is compiled out of release builds. Verified screenshot:
`docs/assets/ios-e2e-dashboard.png`.

## UI test (2026-11-17)

`AlphaLoopIOSUITests` launches the app with the DEBUG auto-login arguments,
asserts the dashboard, then visits 策略 / 执行 / 风控 / 设置. It passed on the
iOS 27.2 simulator against a local backend:

```bash
xcodebuild test -project AlphaLoopIOS.xcodeproj -scheme AlphaLoopIOS \
  -destination 'platform=iOS Simulator,id=<booted>' \
  -derivedDataPath .iosbuild CODE_SIGNING_ALLOWED=NO
```
