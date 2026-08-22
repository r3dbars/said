# Said Agent Guide

## Source of truth

Read `docs/PRD.md` before changing product behavior. Requirements marked
**LOCKED** are owner decisions. The final product name is **Said** even where
older source anchors or historical material use the working name Listen.

The product rule is **Hear. Read. Gone.** Said captions Mac system audio and
leaves no recording or transcript behind.

## Current milestone

PR 0 proved the model/runtime path on the available M5 Max and completed a
virtual M1 correctness/memory stress run. The owner directed work toward a
locally playable alpha on 2026-08-22. The native shell and end-to-end Core Audio
-> Parakeet -> caption path are now implemented.

The owner explicitly corrected the capture architecture after macOS placed the
ScreenCaptureKit build under Screen & System Audio Recording. Said now uses a
private Core Audio process tap so it appears under System Audio Recording Only.
This decision supersedes the older ScreenCaptureKit requirement.

Keep these public-release gates open:

- physical M1 16 GB real-time performance receipt
- model-license/provenance human review
- signed and notarized clean-machine install

## Hard boundaries

- Never add a cloud, Apple Speech, Whisper, or Nemotron fallback.
- Never add microphone capture, screen output, a model picker, or a local
  service/helper process.
- Never log or persist spoken content outside explicit licensed test fixtures.
- Never use moving dependency branches or unverified model bytes.
- Do not claim hardware or performance behavior without a device receipt.
- Keep runtime-specific types behind a narrow adapter.

## Verification

For PR 0, run the repository scripts and record exact commands, device details,
pins, latency, caption churn, memory, and gaps in `docs/model-spike.md`. Stop and
report if true streaming, Metal, the license chain, or the release latency gate
cannot be proven without violating a locked decision.
