#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
plist="$repo_root/Resources/Info.plist"
app_support="$HOME/Library/Application Support/Said"

fail() {
  print -u2 "privacy smoke failed: $1"
  exit 1
}

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

if rg -n 'Sentry|Crashlytics|TelemetryDeck|Mixpanel|Amplitude|PostHog' \
  "$repo_root/Package.swift" "$repo_root/Sources"; then
  fail "a prohibited analytics or crash-reporting SDK appears in the shipping path"
fi

# Caption values may be measured by length, but must never be interpolated as
# content into SaidLogger calls.
if rg -UP 'SaidLogger\.[a-z]+\((?:(?!\)\n).)*(snapshot\.(committed|tentative)(?!\.count)|model\.(committedText|tentativeText))' \
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

if strings "$binary" | rg -q 'NSMicrophoneUsageDescription|NSScreenCaptureUsageDescription'; then
  fail "forbidden permission string is embedded in Said"
fi

print "privacy smoke passed"
print -r -- "- System Audio Recording Only usage copy present"
print -r -- "- no microphone, screen-capture, camera, or clipboard permission/API path"
print -r -- "- no analytics or third-party crash SDK"
print -r -- "- no caption-content logger interpolation"
print -r -- "- no audio/transcript-like files in Said application storage"
