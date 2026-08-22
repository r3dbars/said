#!/bin/zsh
set -euo pipefail

mode=${1:-run}
repo_root=${0:A:h:h}
app_name=Said
bundle_id=app.said.Said
app_bundle="$repo_root/dist/$app_name.app"
app_macos="$app_bundle/Contents/MacOS"

pkill -x "$app_name" >/dev/null 2>&1 || true

"$repo_root/scripts/build-app.sh" --configuration debug --adhoc

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
