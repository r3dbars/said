# Release checklist

## Local alpha receipt

This produces a release-optimized, ad-hoc-signed DMG for testing on this Mac.
It is deliberately named `local-alpha` and is not a public distribution build.

```bash
./scripts/package-dmg.sh --adhoc
./scripts/verify-release.sh --allow-adhoc dist/Said-0.1.0-alpha-local-alpha.dmg
```

## Developer ID prerequisites

- A valid `Developer ID Application` certificate in the login keychain.
- Apple notarization credentials stored with `notarytool` under a named
  keychain profile.
- Human approval of the exact model/conversion license chain.
- All M1/16 GB, privacy, long-run, and clean-machine gates green.

No App Sandbox entitlement is added. Said is distributed directly, uses no
privileged entitlement, and relies on `NSAudioCaptureUsageDescription` plus the
macOS System Audio Recording Only consent surface.

## Signed and notarized build

```bash
export SAID_SIGNING_IDENTITY='Developer ID Application: Example (TEAMID)'
export SAID_NOTARY_PROFILE='said-notary'
./scripts/package-dmg.sh --notarize
./scripts/verify-release.sh dist/Said-0.1.0-alpha.dmg
```

The build script signs `CTranscribe.framework` first, signs Said with Hardened
Runtime and a secure timestamp, signs the DMG, submits it with `notarytool`, and
staples the accepted ticket. The verifier checks bundle layout, arm64-only
architecture, privacy keys, licenses, nested signatures, Developer ID,
Hardened Runtime, Gatekeeper acceptance, and the stapled ticket.

## Current machine status

`security find-identity -p codesigning -v` reports zero valid identities.
Therefore this Mac can prove packaging and ad-hoc local installation, but it
cannot honestly produce or validate the final Developer ID/notarized release.
