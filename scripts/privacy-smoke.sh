#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
plist="$repo_root/Resources/Info.plist"
app_support="$HOME/Library/Application Support/Said"
receipt_dir="$repo_root/Artifacts/Receipts/Privacy"
run_id=$(/bin/date -u '+%Y%m%dT%H%M%SZ')
receipt="$receipt_dir/privacy-$run_id.json"

fail() {
  print -u2 "privacy smoke failed: $1"
  exit 1
}

if ! command -v rg >/dev/null 2>&1; then
  fail "rg (ripgrep) is required"
fi

plist_value=$(/usr/libexec/PlistBuddy -c 'Print :NSAudioCaptureUsageDescription' "$plist")
[[ -n "$plist_value" ]] || fail "missing System Audio usage copy"

for forbidden_key in NSMicrophoneUsageDescription NSScreenCaptureUsageDescription NSCameraUsageDescription; do
  if /usr/libexec/PlistBuddy -c "Print :$forbidden_key" "$plist" >/dev/null 2>&1; then
    fail "forbidden Info.plist key $forbidden_key is present"
  fi
done

if rg -n 'import ScreenCaptureKit|\bSCStream\b|AVAudioRecorder|requestRecordPermission|NSPasteboard' \
  "$repo_root/Sources/SaidApp" "$repo_root/Sources/SaidCapture"; then
  fail "a prohibited screen, microphone-recording, or clipboard API appears in the shipping path"
fi

if rg -n 'Privacy_ScreenCapture' "$repo_root/Sources"; then
  fail "Privacy_ScreenCapture appears in Sources"
fi

if rg -n 'Sentry|Crashlytics|TelemetryDeck|Mixpanel|Amplitude|PostHog' \
  "$repo_root/Package.swift" "$repo_root/Sources"; then
  fail "a prohibited analytics or crash-reporting SDK appears in the shipping path"
fi

# Model installation is the only shipping network implementation. Opening the
# public GitHub Releases page is an explicit user action delegated to the
# browser; capture, normalization, inference, core state, and UI must not own a
# networking API.
if rg -n 'URLSession|URLRequest|import Network|NWConnection|NWPathMonitor|WebSocket|CFNetwork' \
  "$repo_root/Sources/SaidApp" \
  "$repo_root/Sources/SaidASR" \
  "$repo_root/Sources/SaidCapture" \
  "$repo_root/Sources/SaidCore"; then
  fail "a networking API appears outside the model-installation boundary"
fi

# Caption values may be measured by length, but must never be interpolated as
# content into SaidLogger calls.
if rg -UP 'SaidLogger\.[a-z]+\((?:(?!\)\n).)*(snapshot\.(committed|tentative)(?!\.count)|model\.(captionWindow|visibleCaptionText))' \
  "$repo_root/Sources/SaidApp"; then
  fail "caption content can reach a logger call"
fi

if [[ -d "$app_support" ]]; then
  content_file=$(find "$app_support" -type f \( \
    -iname '*.wav' -o -iname '*.aiff' -o -iname '*.m4a' -o -iname '*.mp3' -o \
    -iname '*.mp4' -o -iname '*.mov' -o -iname '*.txt' -o -iname '*.md' \
  \) -print -quit)
  [[ -z "$content_file" ]] || fail "unexpected content-like file in app storage: $content_file"
fi

cd "$repo_root"
swift build --product Said >/dev/null

binary="$(swift build --show-bin-path)/Said"
[[ -x "$binary" ]] || fail "Said executable was not produced"

if strings "$binary" | rg -q 'NSMicrophoneUsageDescription|NSScreenCaptureUsageDescription|Privacy_ScreenCapture'; then
  fail "forbidden permission string is embedded in Said"
fi

/bin/mkdir -p "$receipt_dir"
commit=$(git -C "$repo_root" rev-parse HEAD)
macos_version=$(/usr/bin/sw_vers -productVersion)
hardware=$(/usr/sbin/sysctl -n machdep.cpu.brand_string)
memory_bytes=$(/usr/sbin/sysctl -n hw.memsize)

/usr/bin/printf '%s\n' \
  '{' \
  '  "status": "passed",' \
  "  \"run_id\": \"$run_id\"," \
  "  \"git_commit\": \"$commit\"," \
  "  \"macos_version\": \"$macos_version\"," \
  "  \"hardware\": \"$hardware\"," \
  "  \"memory_bytes\": $memory_bytes," \
  '  "system_audio_usage_copy_present": true,' \
  '  "forbidden_usage_keys_present": false,' \
  '  "prohibited_capture_apis_present": false,' \
  '  "analytics_or_crash_sdk_present": false,' \
  '  "caption_content_logging_path_present": false,' \
  '  "caption_network_api_path_present": false,' \
  '  "content_like_app_storage_files_present": false,' \
  '  "forbidden_permission_strings_present": false,' \
  '  "runtime_network_observation_performed": false,' \
  '  "content_retained": false' \
  '}' >"$receipt"

print "privacy smoke passed"
print -r -- "- System Audio Recording Only usage copy present"
print -r -- "- no microphone, screen-capture, camera, or clipboard permission/API path"
print -r -- "- no analytics or third-party crash SDK"
print -r -- "- no networking API in capture, ASR, core, or app UI modules"
print -r -- "- no caption-content logger interpolation"
print -r -- "- no audio/transcript-like files in Said application storage"
print -r -- "- receipt: $receipt"
