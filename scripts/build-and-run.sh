#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
verify=false

while (( $# > 0 )); do
  case "$1" in
    --verify)
      verify=true
      shift
      ;;
    *)
      print -u2 "usage: $0 [--verify]"
      exit 2
      ;;
  esac
done

"$repo_root/scripts/build-app.sh" --configuration release --adhoc
if [[ "$verify" == true ]]; then
  "$repo_root/scripts/verify-release.sh" --allow-adhoc "$repo_root/dist/Said.app"
fi

/usr/bin/osascript -e 'tell application "Said" to quit' 2>/dev/null || true
for _ in {1..50}; do
  if ! /usr/bin/pgrep -f "$repo_root/dist/Said.app/Contents/MacOS/Said" >/dev/null; then
    break
  fi
  /bin/sleep 0.1
done
/usr/bin/open -n "$repo_root/dist/Said.app"

print "Said is running from $repo_root/dist/Said.app"
print "If macOS asks, allow Said under System Settings > Privacy & Security > System Audio Recording Only."
