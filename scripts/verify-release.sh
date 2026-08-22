#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
allow_adhoc=false
allow_development=false
artifact=""

while (( $# > 0 )); do
  case "$1" in
    --allow-adhoc)
      allow_adhoc=true
      shift
      ;;
    --allow-development)
      allow_development=true
      shift
      ;;
    *)
      artifact=$1
      shift
      ;;
  esac
done

[[ -n "$artifact" ]] || {
  print -u2 "usage: $0 [--allow-adhoc | --allow-development] <Said.app|Said.dmg>"
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
[[ -f "$app/Contents/Resources/Said.icns" ]] || { print -u2 "missing Said app icon"; exit 1; }
[[ $(plutil -extract CFBundleIconFile raw "$app/Contents/Info.plist") == Said.icns ]] || { print -u2 "invalid Said app icon declaration"; exit 1; }
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

write_receipt() {
  local signing_tier=$1
  local hardened_runtime=$2
  local gatekeeper_accepted=$3
  local notarization_validated=$4
  local receipt_dir="$repo_root/Artifacts/Receipts/Release"
  local run_id=$(/bin/date -u '+%Y%m%dT%H%M%SZ')
  local receipt="$receipt_dir/release-$run_id.json"
  local artifact_kind=app
  local digest_subject="$app/Contents/MacOS/Said"
  if [[ "$artifact" == *.dmg ]]; then
    artifact_kind=dmg
    digest_subject="$artifact"
  fi
  local artifact_size_bytes=$(/usr/bin/stat -f '%z' "$digest_subject")
  local artifact_sha256=$(/usr/bin/shasum -a 256 "$digest_subject" | /usr/bin/awk '{print $1}')
  local verifier_commit=$(git -C "$repo_root" rev-parse HEAD)
  local worktree_clean=true
  if [[ -n $(git -C "$repo_root" status --porcelain --untracked-files=no) ]]; then
    worktree_clean=false
  fi
  local macos_version=$(/usr/bin/sw_vers -productVersion)
  local hardware=$(/usr/sbin/sysctl -n machdep.cpu.brand_string)
  local memory_bytes=$(/usr/sbin/sysctl -n hw.memsize)
  local app_version=$(plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist")
  local app_build=$(plutil -extract CFBundleVersion raw "$app/Contents/Info.plist")

  /bin/mkdir -p "$receipt_dir"
  /usr/bin/printf '%s\n' \
    '{' \
    '  "status": "passed",' \
    "  \"run_id\": \"$run_id\"," \
    "  \"verifier_git_commit\": \"$verifier_commit\"," \
    "  \"verifier_worktree_clean\": $worktree_clean," \
    "  \"macos_version\": \"$macos_version\"," \
    "  \"hardware\": \"$hardware\"," \
    "  \"memory_bytes\": $memory_bytes," \
    "  \"app_version\": \"$app_version\"," \
    "  \"app_build\": \"$app_build\"," \
    "  \"artifact_kind\": \"$artifact_kind\"," \
    "  \"artifact_size_bytes\": $artifact_size_bytes," \
    "  \"artifact_sha256\": \"$artifact_sha256\"," \
    "  \"signing_tier\": \"$signing_tier\"," \
    "  \"hardened_runtime\": $hardened_runtime," \
    "  \"gatekeeper_accepted\": $gatekeeper_accepted," \
    "  \"notarization_validated\": $notarization_validated," \
    '  "model_bundled": false,' \
    '  "content_retained": false' \
    '}' >"$receipt"
  print "verification receipt: $receipt"
}

if [[ "$details" == *"Signature=adhoc"* ]]; then
  [[ "$allow_adhoc" == true ]] || { print -u2 "release artifact is ad-hoc signed"; exit 1; }
  print "local-alpha verification passed (ad-hoc signature; not distributable)"
  write_receipt adhoc false false false
  exit 0
fi

[[ "$details" == *"runtime"* ]] || { print -u2 "Hardened Runtime is not enabled"; exit 1; }
if [[ "$details" == *"Authority=Apple Development:"* ]]; then
  [[ "$allow_development" == true ]] || { print -u2 "release artifact has a local Apple Development signature"; exit 1; }
  print "local development verification passed (stable Apple Development signature; not distributable)"
  write_receipt apple-development true false false
  exit 0
fi

[[ "$details" == *"Authority=Developer ID Application:"* ]] || { print -u2 "missing Developer ID Application signature"; exit 1; }
spctl -a -vv --type execute "$app"
if [[ "$artifact" == *.dmg ]]; then
  codesign --verify --verbose=2 "$artifact"
  xcrun stapler validate "$artifact"
fi
print "release verification passed"
if [[ "$artifact" == *.dmg ]]; then
  write_receipt developer-id true true true
else
  write_receipt developer-id true true false
fi
