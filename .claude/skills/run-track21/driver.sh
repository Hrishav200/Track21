#!/usr/bin/env bash
# Driver for building, launching, and driving the Track21 iOS app in the
# Simulator. Run from the repo root (the directory containing Track21.xcodeproj).
#
# Subcommands:
#   setup-xcode                 Point xcode-select at Xcode.app (needed once per machine)
#   boot [device] [os]          Boot a simulator and open Simulator.app
#   build                       Build the app for the Simulator
#   launch [device] [os]        Install + launch the already-built app, screenshot it
#   screenshot <out.png> [dev]  Screenshot whatever is currently on screen
#   uitest [TestID] [outDir]    Run an XCUITest and export its screenshot attachments
#
# Examples:
#   ./driver.sh boot
#   ./driver.sh build
#   ./driver.sh launch
#   ./driver.sh uitest Track21UITests/SmokeFlowUITests/testGuestAddHabitFlow /tmp/out
set -euo pipefail

PROJECT="Track21.xcodeproj"
SCHEME="Track21"
BUNDLE_ID="com.yourbaecodes.trackHabit"
DEFAULT_DEVICE="iPhone 16"
DEFAULT_OS="18.5"

die() { echo "error: $*" >&2; exit 1; }

require_repo_root() {
  [ -d "$PROJECT" ] || die "run this from the repo root (directory containing $PROJECT)"
}

udid_for() {
  local device="$1" os="$2"
  local os_dashed="${os//./-}"
  xcrun simctl list devices -j \
    | python3 -c "
import json,sys
data = json.load(sys.stdin)
for runtime, devices in data['devices'].items():
    if '$os_dashed' not in runtime:
        continue
    for d in devices:
        if d['name'] == '$device':
            print(d['udid']); sys.exit(0)
sys.exit(1)
" || die "no simulator named '$device' with OS $os. List options: xcrun simctl list devices available"
}

cmd_setup_xcode() {
  if xcodebuild -version >/dev/null 2>&1; then
    echo "Xcode already active: $(xcodebuild -version | head -1)"
    return
  fi
  echo "Switching active developer directory to Xcode.app (requires admin password)..."
  osascript -e 'do shell script "xcode-select -s /Applications/Xcode.app/Contents/Developer" with administrator privileges'
  xcodebuild -version
}

cmd_boot() {
  require_repo_root
  local device="${1:-$DEFAULT_DEVICE}" os="${2:-$DEFAULT_OS}"
  local udid
  udid=$(udid_for "$device" "$os")
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b
  open -a Simulator --args -CurrentDeviceUDID "$udid"
  echo "Booted $device (iOS $os): $udid"
}

cmd_build() {
  require_repo_root
  xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination 'generic/platform=iOS Simulator' \
    -configuration Debug \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO
}

find_app_path() {
  find "$HOME/Library/Developer/Xcode/DerivedData/${SCHEME}"-*/Build/Products/Debug-iphonesimulator \
    -maxdepth 1 -iname "*.app" 2>/dev/null | head -1
}

cmd_launch() {
  require_repo_root
  local device="${1:-$DEFAULT_DEVICE}" os="${2:-$DEFAULT_OS}"
  local udid app_path
  udid=$(udid_for "$device" "$os")
  app_path=$(find_app_path)
  [ -n "$app_path" ] || die "no built .app found — run '$0 build' first"
  xcrun simctl install "$udid" "$app_path"
  xcrun simctl launch "$udid" "$BUNDLE_ID"
  sleep 2
  local shot="/tmp/track21-launch-$(date +%s).png"
  xcrun simctl io "$udid" screenshot "$shot"
  echo "Screenshot: $shot"
}

cmd_screenshot() {
  local out="${1:?usage: $0 screenshot <out.png> [device] [os]}"
  local device="${2:-$DEFAULT_DEVICE}" os="${3:-$DEFAULT_OS}"
  local udid
  udid=$(udid_for "$device" "$os")
  xcrun simctl io "$udid" screenshot "$out"
  echo "Screenshot: $out"
}

cmd_uitest() {
  require_repo_root
  local test_id="${1:-Track21UITests/SmokeFlowUITests/testGuestAddHabitFlow}"
  local out_dir="${2:-/tmp/track21-uitest-$(date +%s)}"
  local device="${3:-$DEFAULT_DEVICE}" os="${4:-$DEFAULT_OS}"
  local result_bundle="$out_dir/result.xcresult"

  mkdir -p "$out_dir"
  rm -rf "$result_bundle"

  local status=0
  xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,name=$device,OS=$os" \
    -only-testing:"$test_id" \
    -resultBundlePath "$result_bundle" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO || status=$?

  xcrun xcresulttool export attachments --path "$result_bundle" --output-path "$out_dir" || true
  echo "Result bundle: $result_bundle"
  echo "Screenshots + manifest.json: $out_dir"
  return $status
}

main() {
  local sub="${1:-}"
  [ -n "$sub" ] || die "usage: $0 <setup-xcode|boot|build|launch|screenshot|uitest> [args...]"
  shift
  case "$sub" in
    setup-xcode) cmd_setup_xcode "$@" ;;
    boot) cmd_boot "$@" ;;
    build) cmd_build "$@" ;;
    launch) cmd_launch "$@" ;;
    screenshot) cmd_screenshot "$@" ;;
    uitest) cmd_uitest "$@" ;;
    *) die "unknown subcommand: $sub" ;;
  esac
}

main "$@"
