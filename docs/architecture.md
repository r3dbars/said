# Architecture decision record

## ADR-001: native Swift with pinned TranscribeCpp

**Status:** proposed pending PR 0 proof  
**Date:** 2026-08-22

Said will be a Swift 6 macOS 26 application. SwiftUI owns setup, settings, and
caption content; AppKit owns lifecycle, menu bar, and the nonactivating panel.
ScreenCaptureKit provides audio-only system capture. Native Apple frameworks
normalize audio. A narrow adapter wraps an exactly pinned `transcribe.cpp`
Apple XCFramework and Parakeet buffered streaming on Metal.

PR 0 must prove the adapter path before app code begins. A new architecture
decision is required if any locked assumption fails; no fallback may be added.

## Boundaries

- `SaidCore`: pure caption, PCM, model-manifest, metrics, and state behavior.
- `SaidCapture`: audio-only SCK lifecycle and normalization.
- `SaidASR`: runtime adapter and Parakeet actor.
- `SaidModel`: download, verification, receipts, and storage.
- `SaidApp`: thin AppKit/SwiftUI composition.

The PR 0 executable is an intentionally temporary product named
`SaidModelSpike`, not the shipping app.

