# PR 0 model feasibility spike

**Status:** functionally proven on the available host; baseline-device gate pending
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
- [ ] Model/conversion/runtime licenses archived; discrepancy is documented, but human license review remains open.
- [x] Metal backend confirmed at runtime (`MTL0`, device kind `metal`).
- [x] Parakeet buffered streaming capability accepted.
- [x] Public-domain JFK fixture produces incremental nonempty text.
- [x] Committed prefix mutation count is zero in every measured configuration.
- [x] Lookahead/feed benchmark matrix completed.
- [x] Stable-prefix agreement 2 vs. 3 classified as N/A for this runtime (see correction below).
- [x] Latency, normalized WER, churn, memory, Metal, and feed percentiles recorded on the available host.
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

### PRD correction: tentative text

The pinned Parakeet implementation advances its family-native committed token
boundary with every published hypothesis. Across the complete matrix,
`tentative` never became nonempty: incremental text arrived entirely through
the append-only `committed` field. This is consistent with the pinned runtime's
`FamilyNativeCommit` implementation, but it means PR 0 cannot truthfully prove
a nonempty model-provided tentative suffix.

The product can render the runtime's append-only text immediately. Before the
caption-polish milestone, decide whether to leave tentative styling dormant or
derive a conservative volatile last-word suffix in Said's adapter. Do not claim
that the model emitted tentative text when it did not.

### Toolchain status

Full Xcode is not installed. The prebuilt XCFramework may be usable with the
Command Line Tools, so the harness build will be attempted before treating this
as a hard blocker. Rebuilding the XCFramework and shipping a signed app require
the full Apple toolchain.

## Benchmark results

Command:

```bash
./scripts/performance-smoke.sh
```

Fixture: `Dependencies/transcribe.cpp/samples/jfk.wav`, an 11-second excerpt of
John F. Kennedy's 1961 inaugural address. The speech is a United States federal
government work in the public domain. The fixture is 16 kHz, mono, PCM16. The
normalized reference is:

> And so my fellow Americans ask not what your country can do for you ask what
> you can do for your country

The final normalized hypothesis matched that reference exactly (WER 0% on this
single smoke fixture). This is a feasibility receipt, not a representative
accuracy evaluation.

### Lookahead matrix

| Lookahead | Feed | Speech to first caption | Feed p50 | Feed p95 | Total processing | Peak RSS |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 160 ms | 80 ms | 880 ms | 25.0 ms | 36.8 ms | 3,593 ms | 874 MB |
| 320 ms | 160 ms | 960 ms | 25.0 ms | 34.4 ms | 1,700 ms | 870 MB |
| 480 ms | 160 ms | 1,120 ms | 25.2 ms | 28.9 ms | 1,690 ms | 871 MB |
| 1,120 ms | 160 ms | 1,440 ms | 0.001 ms | 27.9 ms | 482 ms | 873 MB |

The low median at 1,120 ms reflects feeds that only buffer input; its larger
inference steps happen less often. Total processing is therefore a more useful
resource comparison than that median alone.

### Feed-block matrix at 320 ms lookahead

| Feed block | Speech to first caption | Feed p50 | Feed p95 | Total processing | Peak RSS |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 80 ms | 960 ms | 0.007 ms | 28.9 ms | 1,712 ms | 870 MB |
| 160 ms | 960 ms | 25.0 ms | 32.1 ms | 1,698 ms | 872 MB |
| 320 ms | 960 ms | 51.8 ms | 69.5 ms | 1,755 ms | 870 MB |

All seven runs used Metal, produced the exact normalized reference, recorded
zero committed mutations, zero `full` versus `committed + tentative`
divergences, and no nonempty tentative suffix. Model load after cache warm-up was
209–217 ms. Raw per-feed JSON and native runtime logs are retained under the
gitignored `Artifacts/Receipts/PR0/` directory on the measurement host.

These are accelerated offline feeds, not wall-clock playback. “Speech to first
caption” uses detected fixture speech onset and the runtime's received-audio
clock; it is the closest deterministic proxy in this spike. Live capture must
measure end-to-end display latency later.

## Decision and remaining gate

The chosen model/runtime path is feasible on Apple silicon and the locked
`5600 / 160 / 160` configuration remains the best starting balance. The 160 ms
lookahead costs roughly twice the total compute on this fixture for only an
80 ms first-caption improvement; 480 ms and 1,120 ms miss the preferred latency
direction.

PR 0 is not fully closed because this machine is an M5 Max with 128 GB, not the
required M1 with 16 GB. The dependency-license archive/human review is also not
complete. Do not present these M5 measurements as proof of the M1 release gate.
