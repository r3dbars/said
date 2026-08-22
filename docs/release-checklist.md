# Release checklist

See the evidence-backed [reliability and privacy verification matrix](reliability-matrix.md)
for the current status of every deterministic, live-hardware, privacy,
performance, and distribution gate. This checklist describes the commands; the
matrix records what they have actually proven.

## Local development receipt

```bash
./scripts/build-and-run.sh --verify
./scripts/run-tests.sh
./scripts/capture-smoke.sh
./scripts/offline-smoke.sh
./scripts/post-quit-privacy-smoke.sh
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

The privacy smoke enforces the static permission, prohibited-API, dependency,
logging, app-storage, binary-string, and caption-path network boundaries. It
writes a content-free JSON receipt under `Artifacts/Receipts/Privacy/` and
marks runtime network observation as unperformed so a static pass cannot be
mistaken for the remaining live offline-network gate.

The offline smoke requires the model to be installed before launch. It uses an
`lsof` polling loop from process identification through model load and real
captioning, plus an overlapping finite `nettop` observation across inference.
It then writes only sample/connection counts under
`Artifacts/Receipts/Offline/`. The passing scope is sampled per-process socket
observation; it is not kernel packet capture.

The post-quit privacy smoke speaks a controlled fixture, requires a fresh
caption revision, quits Said, and then searches the Said unified-log interval,
preferences, and app-owned writable locations for the fixture's distinctive
words. It separately rejects audio- or transcript-like files. Its receipt
contains only counts and boolean facts; raw observations are deleted. The gate
does not claim physical memory or swap erasure.

The soak command defaults to 30 minutes. Every 30 seconds it plays a controlled
phrase and requires a fresh caption revision, so a pipeline that works once and
then silently stops cannot pass. It samples resident memory after warmup,
enforces peak rather than merely final RSS growth, detects pipeline failure
signatures, and writes a content-free JSON receipt under
`Artifacts/Receipts/Soak/`. Run the same harness for 60 and 240 minutes for the
long-session release gates. Use `--speech-interval` only for short harness
validation; release receipts use the 30-second default.

## Local alpha receipt

This produces a release-optimized, ad-hoc-signed DMG for testing on this Mac.
It is deliberately named `local-alpha` and is not a public distribution build.

```bash
./scripts/package-dmg.sh --adhoc
./scripts/verify-release.sh --allow-adhoc dist/Said-0.1.0-alpha-local-alpha.dmg
```

Successful verification writes a content-free JSON receipt under
`Artifacts/Receipts/Release/` containing the exact artifact SHA-256, app
version, verifier commit/cleanliness, signing tier, and explicit booleans for
Hardened Runtime, Gatekeeper, notarization, and model bundling. An ad-hoc
receipt records those public-release gates as false rather than presenting a
local artifact as distributable.

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
