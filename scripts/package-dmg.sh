#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
signing_identity=${SAID_SIGNING_IDENTITY:-}
notary_profile=${SAID_NOTARY_PROFILE:-}
use_adhoc=false
notarize=false

while (( $# > 0 )); do
  case "$1" in
    --adhoc)
      use_adhoc=true
      shift
      ;;
    --notarize)
      notarize=true
      shift
      ;;
    *)
      print -u2 "usage: $0 [--adhoc] [--notarize]"
      exit 2
      ;;
  esac
done

if [[ "$use_adhoc" == true && "$notarize" == true ]]; then
  print -u2 "an ad-hoc build cannot be notarized"
  exit 2
fi
if [[ "$use_adhoc" != true && -z "$signing_identity" ]]; then
  print -u2 "set SAID_SIGNING_IDENTITY or pass --adhoc for a local-alpha DMG"
  exit 1
fi
if [[ "$notarize" == true && -z "$notary_profile" ]]; then
  print -u2 "set SAID_NOTARY_PROFILE to notarize"
  exit 1
fi

version=$(plutil -extract CFBundleShortVersionString raw "$repo_root/Resources/Info.plist")
if [[ "$use_adhoc" == true ]]; then
  "$repo_root/scripts/build-app.sh" --configuration release --adhoc
  dmg="$repo_root/dist/Said-$version-local-alpha.dmg"
else
  "$repo_root/scripts/build-app.sh" --configuration release --signing-identity "$signing_identity"
  dmg="$repo_root/dist/Said-$version.dmg"
fi

staging=$(mktemp -d /private/tmp/said-dmg.XXXXXX)
cleanup() { rm -rf "$staging" }
trap cleanup EXIT

/usr/bin/ditto "$repo_root/dist/Said.app" "$staging/Said.app"
ln -s /Applications "$staging/Applications"
rm -f "$dmg"
hdiutil create -volname Said -srcfolder "$staging" -ov -format UDZO "$dmg"
hdiutil verify "$dmg"

if [[ "$use_adhoc" != true ]]; then
  codesign --force --timestamp --sign "$signing_identity" "$dmg"
  codesign --verify --verbose=2 "$dmg"
fi

if [[ "$notarize" == true ]]; then
  xcrun notarytool submit "$dmg" --keychain-profile "$notary_profile" --wait
  xcrun stapler staple "$dmg"
  xcrun stapler validate "$dmg"
fi

print "$dmg"
