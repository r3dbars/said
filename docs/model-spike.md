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
| Baseline class | M-series; exact chip and memory receipt pending |

## Required evidence

- [ ] Exact `transcribe.cpp` source commit.
- [ ] Reproducible Apple XCFramework build and SHA-256.
- [ ] Model revision, filename, byte size, and SHA-256 independently verified.
- [ ] Model/conversion/runtime licenses archived and discrepancy documented.
- [ ] Metal backend confirmed at runtime.
- [ ] Parakeet buffered streaming capability accepted.
- [ ] Licensed fixture produces nonempty committed and tentative text.
- [ ] Committed prefix mutation count is zero.
- [ ] Lookahead/feed/agreement benchmark matrix completed.
- [ ] Latency, WER where possible, churn, memory, CPU/Metal, and feed percentiles recorded.
- [ ] M1 16 GB receipt completed.

## Current blocker

Full Xcode is not installed. The Apple XCFramework/Metal path may require tools
not present in the Command Line Tools package. Source inspection and the
reproducible harness can proceed; hardware proof cannot be claimed until the
required Apple toolchain is installed.

## Benchmark results

Pending. Results must include exact command, fixture license/source, runtime and
model pins, device chip/memory, configuration, raw measurements, and conclusion.

## Decision

Pending. Do not substitute another model or runtime if this spike fails.

