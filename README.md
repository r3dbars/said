# Said

**See what's being said.**

Said is a native macOS utility that turns audio playing through your Mac into
live English captions. Speech recognition runs on-device. Said has no account,
does not upload audio or captions, and does not save a transcript.

> Hear. Read. Gone.

## Status

Said now runs as a playable native menu-bar app. A private Core Audio process
tap captures Mac playback under the **System Audio Recording Only** permission,
normalizes it to 16 kHz mono in memory, and streams it through Parakeet Unified
EN 0.6B Q8_0 using pinned `transcribe.cpp` Swift bindings on Metal. Captions
appear in a floating two-line panel and are never persisted by Said.

The end-to-end path is proven on the available M5 Max. The production model
manager now supports resumable download, exact size/SHA-256 verification,
atomic installation, receipts, reinstall, and removal. The required physical
M1/16 GB release receipt and signed/notarized distribution remain outstanding.

To build, package, and launch the current local alpha:

```bash
./scripts/build-and-run.sh --verify
```

To reproduce the available-host proof:

```bash
./scripts/bootstrap.sh
./scripts/download-model.sh
./scripts/run-tests.sh
./scripts/streaming-smoke.sh
./scripts/capture-smoke.sh
./scripts/performance-smoke.sh
./scripts/privacy-smoke.sh
```

To build and verify a local-only release DMG:

```bash
./scripts/package-dmg.sh --adhoc
./scripts/verify-release.sh --allow-adhoc dist/Said-0.1.0-alpha-local-alpha.dmg
```

See [the release checklist](docs/release-checklist.md) for the Developer ID and
notarization path. A `local-alpha` DMG is intentionally not a public release.

Read [the product requirements](docs/PRD.md) and
[the model spike](docs/model-spike.md) for current evidence and blockers.

## Locked V1 boundary

- macOS 26 and Apple silicon only.
- Mac system audio only; no microphone or screen pixels.
- Parakeet Unified EN 0.6B Q8_0 only unless benchmarks reject it.
- No cloud inference, model picker, fallback recognizer, account, analytics,
  recording, transcript history, pause, rewind, save, translation, summary, or
  speaker labels.

## License

Said application code is MIT licensed. Runtime and model artifacts retain their
own licenses and notices. Public distribution is blocked until the exact pinned
model and conversion license chain receives human review.
