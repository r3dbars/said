# Contributing to Said

Said has one job: turn audio playing through a Mac into calm, readable local
captions. Contributions are welcome when they make that loop clearer, more
reliable, more accessible, or easier to verify.

Start by reading [`AGENTS.md`](AGENTS.md), the locked
[`docs/PRD.md`](docs/PRD.md), and the
[`docs/architecture.md`](docs/architecture.md). A convenient feature is not a
reason to broaden the product. Saved transcripts, microphone capture, cloud
inference, accounts, fallback recognizers, translation, summaries, and model
selection remain out of scope.

## Set up a development checkout

Said requires an Apple-silicon Mac running macOS 26 or later with Xcode 26 and
Swift 6.

```bash
git clone --recurse-submodules https://github.com/r3dbars/said.git
cd said
./scripts/bootstrap.sh
./scripts/run-tests.sh
./scripts/build-and-run.sh --verify
```

`bootstrap.sh` reads the checked-in runtime lock, verifies the exact submodule
commit, archive size and SHA-256 when present, and the extracted macOS runtime
binary. It does not download the speech model. Install the model through Said's
setup window when exercising the real caption path.

## Make a focused change

Keep pure behavior in `SaidCore`, capture and normalization in `SaidCapture`,
runtime-specific recognition behind `SaidASR`, verified downloads in
`SaidModel`, and AppKit/SwiftUI composition in `SaidApp`.

Every change should preserve these boundaries:

- Never log or persist spoken content.
- Never add network access to capture, recognition, core, or caption UI code.
- Never request microphone, screen-pixel, camera, clipboard, Accessibility, or
  Full Disk Access permissions.
- Never load unverified model or runtime bytes.
- Never represent a framework, hardware, latency, permission, thermal, or
  long-run claim as proven by a narrower unit test.
- Never weaken a failing privacy or stability gate to make a pull request pass.

Add a regression fixture for each failure you fix. Test fixtures must be owned,
public domain, or properly licensed; do not commit customer calls, meetings, or
other private audio.

## Verify before opening a pull request

Always run:

```bash
./scripts/bootstrap.sh
./scripts/run-tests.sh
./scripts/build-and-run.sh --verify
```

Run the relevant hardware script when your change touches that boundary:

```bash
./scripts/streaming-smoke.sh
./scripts/capture-smoke.sh
./scripts/offline-smoke.sh
./scripts/post-quit-privacy-smoke.sh
./scripts/soak-smoke.sh --minutes 30
```

These scripts write content-free local receipts under the gitignored
`Artifacts/Receipts/` tree. Do not commit raw logs, audio, caption text, the
731 MB model, credentials, or locally signed release artifacts.

## Pull request evidence

Describe:

- What changed and what intentionally did not change.
- User-visible behavior.
- Privacy and permission impact.
- Exact commands run and their results.
- Hardware and OS used for manual evidence.
- Performance measurements for capture or recognition changes.
- Screenshots for visible changes.
- Remaining unproven behavior.

The current evidence ledger is
[`docs/reliability-matrix.md`](docs/reliability-matrix.md). Update it only when
new evidence truly changes a gate's state.

## Distribution

Local builds are ad-hoc signed by default and are not public releases. Do not
publish a DMG or describe Said as release-ready until every gate in
[`docs/release-checklist.md`](docs/release-checklist.md) is satisfied, including
model-license review, physical M1/16 GB measurements, long-run tests, Developer
ID signing, notarization, and clean-machine verification.
