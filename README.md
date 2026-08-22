# Said

**See what's being said.**

Said is a native macOS utility that turns audio playing through your Mac into
live English captions. Speech recognition runs on-device. Said has no account,
does not upload audio or captions, and does not save a transcript.

> Hear. Read. Gone.

## Status

Said's PR 0 path now streams Parakeet Unified EN 0.6B Q8_0 through pinned
`transcribe.cpp` Swift bindings on Metal. The reproducible spike passes on the
available M5 Max; the required M1/16 GB baseline receipt is still outstanding.
The app UI does not exist yet.

To reproduce the available-host proof:

```bash
./scripts/bootstrap.sh
./scripts/download-model.sh
./scripts/streaming-smoke.sh
./scripts/performance-smoke.sh
```

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
