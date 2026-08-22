#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
verify=false
local_identity=${SAID_LOCAL_SIGNING_IDENTITY:-}

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

if [[ -z "$local_identity" ]]; then
  local_identity=$(security find-identity -p codesigning -v 2>/dev/null \
    | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' \
    | head -n 1)
fi

if [[ -n "$local_identity" ]]; then
  "$repo_root/scripts/build-app.sh" \
    --configuration release \
    --signing-identity "$local_identity"
  if [[ "$verify" == true ]]; then
    "$repo_root/scripts/verify-release.sh" \
      --allow-development \
      "$repo_root/dist/Said.app"
  fi
  print "Signed with stable local identity: $local_identity"
else
  "$repo_root/scripts/build-app.sh" --configuration release --adhoc
  if [[ "$verify" == true ]]; then
    "$repo_root/scripts/verify-release.sh" --allow-adhoc "$repo_root/dist/Said.app"
  fi
  print "No Apple Development identity found; used an ad-hoc local signature."
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
