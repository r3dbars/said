# Release checklist

## Local development receipt

```bash
./scripts/build-and-run.sh --verify
./scripts/run-tests.sh
./scripts/capture-smoke.sh
./scripts/soak-smoke.sh --minutes 30
```

`build-and-run.sh` uses an explicitly configured `SAID_LOCAL_SIGNING_IDENTITY`
only when the developer has independently verified that identity's trust
chain. Otherwise it produces an explicitly labeled ad-hoc build. A trusted
Apple Development identity gives local builds a stable designated requirement
so macOS can preserve System Audio consent across rebuilds; an ad-hoc build may
need consent again after rebuilding. Neither local signature is a public
release signature.

The capture smoke plays a short synthetic phrase through macOS and checks only
content-free operational logs for proof that audio reached the local caption
pipeline. It never inspects or persists recognized text. A successful run
writes a content-free JSON receipt under `Artifacts/Receipts/Capture/` with the
tested commit, machine details, elapsed time, and boolean proof of the local
Metal model and caption revision.

The soak command defaults to 30 minutes. It continuously exercises local
captioning, samples resident memory after warmup, detects pipeline failure
signatures, and writes a content-free JSON receipt under
`Artifacts/Receipts/Soak/`. Run the same harness for 60 and 240 minutes for the
long-session release gates.

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

`security find-identity -p codesigning -v` reports one Apple Development
identity and no Developer ID Application identity. The development certificate
itself validates, but a separately launched `codesign --verify` reports
`CSSMERR_TP_NOT_TRUSTED` for artifacts it signs. Said therefore defaults to a
valid ad-hoc local build on this Mac and does not automatically select that
identity. The machine cannot honestly produce or validate the final Developer
ID/notarized release.
