# PR 0 model feasibility spike

**Status:** in progress  
**Product:** Said  
**Gate:** do not begin PR 1 until every required proof is present.

## Environment

| Field | Value |
| --- | --- |
| Host architecture | Apple silicon (`arm64`) |
| macOS | 26.6.2 |
| Swift | 6.3.3 |
| Developer tools | Command Line Tools only; full Xcode currently missing |
| Available host | MacBook Pro (Mac17,7), Apple M5 Max, 128 GB |
| Required baseline | M1, 16 GB (not available on this host; separate receipt required) |

## Required evidence

- [x] Exact `transcribe.cpp` source commit: `ea077b87590bcfb090d7c38c03ab36cd1c7005d3` (`v0.2.1`).
- [x] Official Apple XCFramework asset independently hashed: `d24e6c0aaff1e628a626f792f74bb7155287a49a5c5bb1179deb73b35f0410f5` (7,660,708 bytes).
- [x] Model revision, filename, byte size, and SHA-256 independently verified from its Git LFS pointer.
- [ ] Model/conversion/runtime licenses archived and discrepancy documented.
- [ ] Metal backend confirmed at runtime.
- [ ] Parakeet buffered streaming capability accepted.
- [ ] Licensed fixture produces nonempty committed and tentative text.
- [ ] Committed prefix mutation count is zero.
- [ ] Lookahead/feed benchmark matrix completed.
- [x] Stable-prefix agreement 2 vs. 3 classified as N/A for this runtime (see correction below).
- [ ] Latency, WER where possible, churn, memory, CPU/Metal, and feed percentiles recorded.
- [ ] M1 16 GB receipt completed.

## Source-audit findings

The pinned runtime exposes synchronous Swift model, session, and stream APIs and
accepts Parakeet's buffered-stream extension. Its official release contains a
dynamic C XCFramework, while the idiomatic Swift wrapper remains source-only.
Said therefore pins the complete source repository and bootstraps the verified
release XCFramework into that checkout's expected local path.

### PRD correction: stable-prefix agreement

`stablePrefixAgreementN` is accepted by the generic API but ignored by
Parakeet's family-native commit implementation in `transcribe.cpp` v0.2.1.
Parakeet publishes native committed chunks, so agreement 2 versus 3 is not a
meaningful benchmark. The field remains set to 3 for explicit configuration,
but PR 0 records the comparison as N/A instead of claiming a measured choice.

The stability receipt must still verify that committed text is append-only and
also report any divergence between `full` and `committed + tentative`.

### Toolchain status

Full Xcode is not installed. The prebuilt XCFramework may be usable with the
Command Line Tools, so the harness build will be attempted before treating this
as a hard blocker. Rebuilding the XCFramework and shipping a signed app require
the full Apple toolchain.

## Benchmark results

Pending. Results must include exact command, fixture license/source, runtime and
model pins, device chip/memory, configuration, raw measurements, and conclusion.

## Decision

Pending. Do not substitute another model or runtime if this spike fails.
