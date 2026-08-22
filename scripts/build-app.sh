#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
configuration=release
signing_identity=${SAID_SIGNING_IDENTITY:-}
use_adhoc=false

while (( $# > 0 )); do
  case "$1" in
    --configuration)
      configuration=$2
      shift 2
      ;;
    --signing-identity)
      signing_identity=$2
      shift 2
      ;;
    --adhoc)
      use_adhoc=true
      shift
      ;;
    *)
      print -u2 "usage: $0 [--configuration debug|release] [--signing-identity NAME | --adhoc]"
      exit 2
      ;;
  esac
done

[[ "$configuration" == debug || "$configuration" == release ]] || {
  print -u2 "configuration must be debug or release"
  exit 2
}
[[ $(uname -m) == arm64 ]] || {
  print -u2 "Said builds only on Apple silicon"
  exit 1
}
if [[ -n "$signing_identity" && "$use_adhoc" == true ]]; then
  print -u2 "choose a Developer ID identity or --adhoc, not both"
  exit 2
fi
if [[ -z "$signing_identity" && "$use_adhoc" != true ]]; then
  print -u2 "set SAID_SIGNING_IDENTITY or pass --adhoc for a local-only build"
  exit 1
fi

app_name=Said
app_bundle="$repo_root/dist/$app_name.app"
app_contents="$app_bundle/Contents"
app_macos="$app_contents/MacOS"
app_frameworks="$app_contents/Frameworks"
license_dir="$app_contents/Resources/Licenses"

cd "$repo_root"
swift build -c "$configuration" --product "$app_name"
bin_dir=$(swift build -c "$configuration" --show-bin-path)
build_binary="$bin_dir/$app_name"
framework_source="$bin_dir/CTranscribe.framework"

[[ "$app_bundle" == "$repo_root/dist/Said.app" ]] || exit 1
rm -rf "$app_bundle"
mkdir -p "$app_macos" "$app_frameworks" "$license_dir"
/usr/bin/ditto "$build_binary" "$app_macos/$app_name"
/usr/bin/ditto "$repo_root/Resources/Info.plist" "$app_contents/Info.plist"
/usr/bin/ditto "$repo_root/Resources/Said.icns" "$app_contents/Resources/Said.icns"
/usr/bin/ditto "$framework_source" "$app_frameworks/CTranscribe.framework"
/usr/bin/ditto "$repo_root/LICENSE" "$license_dir/Said-LICENSE.txt"
/usr/bin/ditto "$repo_root/THIRD_PARTY_LICENSES.md" "$license_dir/THIRD_PARTY_LICENSES.md"
/usr/bin/ditto "$repo_root/docs/privacy.md" "$license_dir/Privacy.md"
/usr/bin/ditto "$repo_root/Dependencies/transcribe.cpp/LICENSE" "$license_dir/transcribe.cpp-LICENSE.txt"
/usr/bin/ditto "$repo_root/Dependencies/transcribe.cpp/THIRD-PARTY-LICENSES.md" "$license_dir/transcribe.cpp-THIRD-PARTY-LICENSES.md"
/usr/bin/ditto "$repo_root/Resources/Licenses/MODEL-NOTICE.txt" "$license_dir/MODEL-NOTICE.txt"
/usr/bin/ditto "$repo_root/Resources/Licenses/NVIDIA-Open-Model-License-2025-10-24.pdf" "$license_dir/NVIDIA-Open-Model-License-2025-10-24.pdf"
chmod +x "$app_macos/$app_name"
install_name_tool -add_rpath @loader_path/../Frameworks "$app_macos/$app_name" 2>/dev/null || true

if [[ -n "$signing_identity" ]]; then
  codesign --force --timestamp --options runtime --sign "$signing_identity" "$app_frameworks/CTranscribe.framework"
  codesign --force --timestamp --options runtime --sign "$signing_identity" "$app_bundle"
else
  codesign --force --sign - "$app_frameworks/CTranscribe.framework"
  codesign --force --sign - "$app_bundle"
fi

codesign --verify --deep --strict --verbose=2 "$app_bundle"
print "$app_bundle"
