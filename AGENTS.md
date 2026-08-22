# Said Agent Guide

## Source of truth

Read `docs/PRD.md` before changing product behavior. Requirements marked
**LOCKED** are owner decisions. The final product name is **Said** even where
older source anchors or historical material use the working name Listen.

The product rule is **Hear. Read. Gone.** Said captions Mac system audio and
leaves no recording or transcript behind.

## Current milestone

Work on PR 0 only until `docs/model-spike.md` proves all exit gates:

- exact `transcribe.cpp` commit and reproducible Apple artifact
- exact Parakeet Unified EN 0.6B Q8_0 revision, size, and SHA-256
- Metal backend
- true buffered streaming through Swift
- committed and tentative text from licensed fixture audio
- benchmark matrix and an M1 16 GB receipt

Do not build the app shell before this gate passes.

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

