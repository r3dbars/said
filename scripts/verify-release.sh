#!/bin/zsh
set -euo pipefail

allow_adhoc=false
artifact=""

while (( $# > 0 )); do
  case "$1" in
    --allow-adhoc)
      allow_adhoc=true
      shift
      ;;
    *)
      artifact=$1
      shift
      ;;
  esac
done

[[ -n "$artifact" ]] || {
  print -u2 "usage: $0 [--allow-adhoc] <Said.app|Said.dmg>"
  exit 2
}
artifact=${artifact:A}
[[ -e "$artifact" ]] || {
  print -u2 "artifact does not exist: $artifact"
  exit 1
}

mount_dir=""
cleanup() {
  if [[ -n "$mount_dir" ]]; then
    hdiutil detach "$mount_dir" -quiet || true
    rmdir "$mount_dir" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if [[ "$artifact" == *.dmg ]]; then
  hdiutil verify "$artifact"
  mount_dir=$(mktemp -d /private/tmp/said-verify.XXXXXX)
  hdiutil attach "$artifact" -nobrowse -readonly -mountpoint "$mount_dir" -quiet
  app="$mount_dir/Said.app"
  [[ -L "$mount_dir/Applications" ]] || { print -u2 "missing Applications shortcut"; exit 1; }
  [[ $(readlink "$mount_dir/Applications") == /Applications ]] || { print -u2 "invalid Applications shortcut"; exit 1; }
else
  app="$artifact"
fi

[[ -x "$app/Contents/MacOS/Said" ]] || { print -u2 "missing Said executable"; exit 1; }
[[ -d "$app/Contents/Frameworks/CTranscribe.framework" ]] || { print -u2 "missing CTranscribe framework"; exit 1; }
[[ -f "$app/Contents/Resources/Licenses/THIRD_PARTY_LICENSES.md" ]] || { print -u2 "missing third-party notices"; exit 1; }
[[ -f "$app/Contents/Resources/Licenses/Privacy.md" ]] || { print -u2 "missing privacy document"; exit 1; }
[[ -f "$app/Contents/Resources/Licenses/NVIDIA-Open-Model-License-2025-10-24.pdf" ]] || { print -u2 "missing NVIDIA model license"; exit 1; }
bundled_model=$(find "$app" -type f -iname '*.gguf' -print -quit)
[[ -z "$bundled_model" ]] || { print -u2 "model must not be bundled: $bundled_model"; exit 1; }

archs=$(lipo -archs "$app/Contents/MacOS/Said")
[[ "$archs" == arm64 ]] || { print -u2 "unexpected architectures: $archs"; exit 1; }

plist="$app/Contents/Info.plist"
[[ $(plutil -extract CFBundleIdentifier raw "$plist") == app.said.Said ]] || exit 1
[[ $(plutil -extract LSMinimumSystemVersion raw "$plist") == 26.0 ]] || exit 1
/usr/libexec/PlistBuddy -c 'Print :NSAudioCaptureUsageDescription' "$plist" >/dev/null
for key in NSMicrophoneUsageDescription NSScreenCaptureUsageDescription NSCameraUsageDescription; do
  if /usr/libexec/PlistBuddy -c "Print :$key" "$plist" >/dev/null 2>&1; then
    print -u2 "forbidden permission key present: $key"
    exit 1
  fi
done

codesign --verify --deep --strict --verbose=2 "$app"
details=$(codesign -dvvv "$app" 2>&1)
if [[ "$details" == *"Signature=adhoc"* ]]; then
  [[ "$allow_adhoc" == true ]] || { print -u2 "release artifact is ad-hoc signed"; exit 1; }
  print "local-alpha verification passed (ad-hoc signature; not distributable)"
  exit 0
fi

[[ "$details" == *"Authority=Developer ID Application:"* ]] || { print -u2 "missing Developer ID Application signature"; exit 1; }
[[ "$details" == *"runtime"* ]] || { print -u2 "Hardened Runtime is not enabled"; exit 1; }
spctl -a -vv --type execute "$app"
if [[ "$artifact" == *.dmg ]]; then
  codesign --verify --verbose=2 "$artifact"
  xcrun stapler validate "$artifact"
fi
print "release verification passed"
