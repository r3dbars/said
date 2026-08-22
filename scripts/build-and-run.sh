#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
verify=false
launch_only=false
local_identity=${SAID_LOCAL_SIGNING_IDENTITY:-}

while (( $# > 0 )); do
  case "$1" in
    --verify)
      verify=true
      shift
      ;;
    --launch-only)
      launch_only=true
      shift
      ;;
    *)
      print -u2 "usage: $0 [--verify] [--launch-only]"
      exit 2
      ;;
  esac
done

if [[ "$launch_only" == true ]]; then
  if [[ ! -d "$repo_root/dist/Said.app" ]]; then
    print -u2 "Said.app does not exist yet. Run $0 --verify first."
    exit 1
  fi
else
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
    print "Used an ad-hoc local signature. Set SAID_LOCAL_SIGNING_IDENTITY only after its trust chain verifies."
  fi
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
if [[ "$launch_only" == true ]]; then
  print "Reused the existing signed bundle so its System Audio permission identity did not change."
else
  print "If macOS asks, allow Said under System Settings > Privacy & Security > System Audio Recording Only."
fi
