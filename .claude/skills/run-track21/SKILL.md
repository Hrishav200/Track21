---
name: run-track21
description: Build, run, and drive the Track21 iOS app in the Simulator. Use when asked to build Track21, launch it, take a screenshot of its UI, run its UI tests, or verify a change actually works in the app.
---

Track21 is a SwiftUI iOS app (Xcode project, no CocoaPods/SPM checkout
needed beyond `xcodebuild -resolvePackageDependencies`). It has no
programmatic API surface worth calling directly — almost all of it is
UI — so the driver is an **XCUITest target** (`Track21UITests`) that
taps through real screens and attaches a screenshot at each step.
Drive it via `.claude/skills/run-track21/driver.sh`, which wraps
`xcodebuild`/`simctl`/`xcresulttool` into one-line subcommands. All
paths below are relative to the repo root (directory containing
`Track21.xcodeproj`).

## Prerequisites

Xcode.app must be installed and be the *active* developer directory
(not just the CLI tools). Check with `xcodebuild -version`; if it
errors with "active developer directory ... is a command line tools
instance", switch it (needs an admin password prompt — this is a
machine-wide setting, confirm with the user before running):

```bash
./.claude/skills/run-track21/driver.sh setup-xcode
```

No other setup is needed — Swift Package dependencies (Supabase,
swift-crypto, etc.) resolve automatically on first build.

## Build

```bash
./.claude/skills/run-track21/driver.sh build
```

Runs `xcodebuild build -scheme Track21 -destination 'generic/platform=iOS Simulator'` with code signing disabled. Takes ~30-90s. Output
`.app` lands under
`~/Library/Developer/Xcode/DerivedData/Track21-*/Build/Products/Debug-iphonesimulator/`.

## Run (agent path)

The driver script (`.claude/skills/run-track21/driver.sh`):

| command | what it does |
|---|---|
| `setup-xcode` | Point `xcode-select` at Xcode.app (one-time, needs admin password) |
| `boot [device] [os]` | Boot a simulator + open Simulator.app. Defaults: `iPhone 16`, `18.5` |
| `build` | Build the app for the Simulator |
| `launch [device] [os]` | Install + launch the already-built app, screenshot to `/tmp/track21-launch-<ts>.png` |
| `screenshot <out.png> [device] [os]` | Screenshot whatever's currently on screen |
| `uitest [TestID] [outDir]` | Run an XCUITest and export its per-step screenshots + `manifest.json` |

**To see the app running and eyeball a screenshot:**

```bash
./.claude/skills/run-track21/driver.sh boot
./.claude/skills/run-track21/driver.sh build
./.claude/skills/run-track21/driver.sh launch
```

Prints the screenshot path, e.g. `/tmp/track21-launch-1783764178.png` — Read it to see the login screen.

**To drive a real end-to-end flow** (guest login → add a habit → habit
appears in the list), use the `SmokeFlowUITests` target already
committed at
[`Track21UITests/SmokeFlowUITests.swift`](../../../Track21UITests/SmokeFlowUITests.swift):

```bash
./.claude/skills/run-track21/driver.sh uitest \
  Track21UITests/SmokeFlowUITests/testGuestAddHabitFlow \
  /tmp/track21-uitest-out
```

This builds (if needed), runs the test on the Simulator, and exports
screenshots named `01-login.png`, `02-home-empty.png`,
`03-add-habit-form.png`, `04-home-with-habit.png` (plus
`manifest.json`) into the output dir. Read the last one to confirm
the flow worked — it should show a "Drink Water — Goal: 8 glasses"
card under "My Habits".

**To exercise a different flow**, add a new `@MainActor func test...()`
to `Track21UITests/SmokeFlowUITests.swift` (or a new file — the project
uses Xcode's file-system-synchronized groups, so any `.swift` file
dropped into `Track21UITests/` is picked up automatically, no
`project.pbxproj` editing needed). Match elements by the SwiftUI
`.accessibilityLabel(...)` text visible in the view source, e.g.
`app.buttons["plus"]`, `app.textFields["Habit name"]`. Call
`attach(app, name: "...")` (already defined in `SmokeFlowUITests.swift`)
after each meaningful step to get a screenshot in the manifest.

## Run (human path)

Open `Track21.xcodeproj` in Xcode, select the `Track21` scheme and an
iPhone simulator, press Cmd-R. Useless in a headless/agent context —
use the driver instead.

## Test

```bash
./.claude/skills/run-track21/driver.sh uitest Track21UITests/SmokeFlowUITests/testGuestAddHabitFlow /tmp/out
```

There's also a `Track21Tests` unit-test target and a stub
`Track21UITestsLaunchTests`, but they're empty scaffolding (Xcode's
defaults) — no real coverage lives there yet.

## Gotchas

- **`xcode-select` may point at CommandLineTools, not Xcode.app.**
  `xcodebuild`/`xcrun simctl` both fail with "requires Xcode" until
  switched (`driver.sh setup-xcode`). `sudo xcode-select -s ...` fails
  non-interactively ("a terminal is required to read the password");
  use `osascript -e 'do shell script "..." with administrator
  privileges'` instead, which triggers a normal macOS GUI password
  prompt.
- **`simctl list devices <os> -j` filters nothing** — the JSON's
  runtime keys use dashes (`iOS-18-5`), not the dotted form
  (`18.5`) you'd naturally pass. The driver's `udid_for()` converts
  dots to dashes before matching; do the same in any script you write
  against `simctl list -j`.
- **Two buttons share one `accessibilityLabel`.** Both the tab-bar "+"
  and the in-list "Add New Habit" button are labeled "Add new habit",
  so `app.buttons["Add new habit"]` throws "Multiple matching
  elements". The tab-bar one is uniquely reachable via its SF Symbol
  name: `app.buttons["plus"]`.
- **`xcodebuild test` runs on a "Clone" of the named simulator**, not
  the one you `simctl boot`ed — that's normal (Xcode clones the
  device for test isolation) and doesn't affect the driver's
  `-only-testing:` + `-resultBundlePath` flow.

## Troubleshooting

- **`xcodebuild: error: tool 'xcodebuild' requires Xcode, but active
  developer directory '/Library/Developer/CommandLineTools' is a
  command line tools instance`**: run `driver.sh setup-xcode`.
- **`sudo: a terminal is required to read the password`**: don't use
  plain `sudo xcode-select -s ...` from a non-interactive shell; use
  the `osascript ... with administrator privileges` form (already in
  `driver.sh`).
- **`Failed to tap "..." Button: ... Multiple matching elements
  found`**: two views share an `accessibilityLabel`; find a more
  specific identifier in the failure's printed element tree (e.g. the
  SF Symbol name) instead of the label.
