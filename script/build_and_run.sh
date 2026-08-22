#!/bin/zsh
set -euo pipefail

mode=${1:-run}
repo_root=${0:A:h:h}
app_name=Said
bundle_id=app.said.Said
dist_dir="$repo_root/dist"
app_bundle="$dist_dir/$app_name.app"
app_contents="$app_bundle/Contents"
app_macos="$app_contents/MacOS"
app_frameworks="$app_contents/Frameworks"

pkill -x "$app_name" >/dev/null 2>&1 || true

cd "$repo_root"
swift build --product "$app_name"
build_binary="$(swift build --show-bin-path)/$app_name"

rm -rf "$app_bundle"
mkdir -p "$app_macos" "$app_frameworks"
cp "$build_binary" "$app_macos/$app_name"
cp "$repo_root/Resources/Info.plist" "$app_contents/Info.plist"
cp -R "$(swift build --show-bin-path)/CTranscribe.framework" "$app_frameworks/CTranscribe.framework"
chmod +x "$app_macos/$app_name"
install_name_tool -add_rpath @loader_path/../Frameworks "$app_macos/$app_name" 2>/dev/null || true
codesign --force --deep --sign - "$app_bundle"

open_app() {
  /usr/bin/open -n "$app_bundle"
}

case "$mode" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$app_macos/$app_name"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == '$app_name'"
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == '$bundle_id'"
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$app_name" >/dev/null
    ;;
  *)
    print -u2 "usage: $0 [run|--debug|--logs|--telemetry|--verify]"
    exit 2
    ;;
esac
