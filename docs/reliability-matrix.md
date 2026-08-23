# Reliability and privacy verification matrix

**Audited:** August 22, 2026  
**Source baseline:** `2c4f7fe`  
**Available hardware:** Apple M5 Max, 128 GB, macOS 26.6.2  
**Required release baseline:** physical Apple M1, 16 GB, current macOS 26

This matrix separates deterministic proof, live hardware proof, and work that
has not happened. A passing unit test is not treated as evidence that a macOS
permission prompt, audio route, display, sleep cycle, thermal state, or clean
installation works on real hardware.

## Evidence states

| State | Meaning |
| --- | --- |
| **Proven** | The requirement has direct evidence at the stated scope. |
| **Partial** | Some layers are proven, but the full user/hardware requirement is not. |
| **Open** | Required evidence is missing. |
| **Blocked** | Work requires a named external prerequisite. |

Local hardware receipts live under gitignored `Artifacts/Receipts/`. Their
content-free summaries are recorded here; recognized text and audio are never
retained in a receipt.

## Core caption path

| Requirement | State | Evidence | Remaining proof |
| --- | --- | --- | --- |
| Pinned Parakeet Unified EN 0.6B Q8_0 loads on Metal | **Proven — M5** | [`model-spike.md`](model-spike.md); all seven measured configurations reported Metal | Repeat release configuration on physical M1/16 GB |
| True incremental streaming through Swift binding | **Proven — M5** | `./scripts/streaming-smoke.sh`; [`model-spike.md`](model-spike.md) | Physical M1 latency receipt |
| Mac playback reaches the local caption pipeline | **Proven — M5** | `./scripts/capture-smoke.sh`; local receipt `capture-20260822T183629Z.json` | Common-app acceptance matrix remains open |
| No committed-prefix mutation | **Proven — fixture matrix** | Seven PR0 runs: zero committed mutations and zero display divergences | Continue as permanent regression metric in long runs |
| Newest caption words remain visible | **Proven — deterministic** | `CaptionWindowingTests` covers long committed text, tentative pressure, styling boundary, and panel height | Human review across displays/text sizes remains open |
| Bounded audio queue and teardown signal | **Proven — deterministic** | `PCMBlockBufferTests` covers ordering, overflow closure, waiter delivery, and finish | Long live runs remain open |
| 48 kHz stereo to continuous 16 kHz mono conversion | **Proven — deterministic** | `AudioNormalizerTests.testInterleavedStereoDownsamplesIntoContinuousMono` | Live format/output-route matrix remains open |
| Speech model is never bundled in the app | **Proven** | `verify-release.sh`; GitHub Quality workflow’s explicit model search | Re-run for final notarized DMG |

## Model lifecycle

| Requirement | State | Evidence | Remaining proof |
| --- | --- | --- | --- |
| Immutable model revision, size, and SHA-256 | **Proven** | [`model-provenance.md`](model-provenance.md); `ModelManagerTests.testPinnedManifestUsesImmutableRevisionURL` | Human license review |
| Resumable download | **Proven — deterministic** | `ResumableModelDownloaderTests.testResumesFromExistingPartialWithValidatedRange` | Manual interrupted first-run download |
| Server ignoring Range cannot duplicate bytes | **Proven — deterministic** | `testServerIgnoringRangeRestartsPartialInsteadOfDuplicatingBytes` | None at this layer |
| Full verification before atomic install | **Proven — deterministic** | `testInstallResumesPartialVerifiesAndWritesReceipt` | Clean-user end-to-end install |
| Corrupt replacement preserves valid model | **Proven — deterministic** | `testCorruptReplacementNeverDestroysExistingValidModel` | Manual reinstall failure UX |
| Completed verified partial installs without another request | **Proven — deterministic** | `testCompletedVerifiedPartialInstallsWithoutAnotherRequest` | None at this layer |
| Offline relaunch after installation | **Proven — sampled M5 observation** | `./scripts/offline-smoke.sh` observes Said with `nettop` and independent `lsof` polling from local model load through real captions | Repeat on physical M1/final artifact; sampled sockets are not kernel packet capture |

## Capture and recovery

| Requirement | State | Evidence | Remaining proof |
| --- | --- | --- | --- |
| System Audio Recording Only; no pixel stream | **Proven — current Mac** | macOS permission UI showed Said in System Audio Recording Only; capture smoke passed; `privacy-smoke.sh` rejects ScreenCaptureKit/pixel paths | Repeat on clean user account |
| No microphone permission or API path | **Proven** | No microphone usage key; privacy gate scans source and built binary | Re-run for final artifact |
| Quiet launch does not report a false stall | **Proven — deterministic** | `CaptureWatchdogPolicyTests.testQuietStartupNeverLooksStalledBeforeFirstBuffer` | Quiet-start manual acceptance on clean user |
| Proven stream stall requests one recovery | **Proven — deterministic** | `testStaleStreamRecoversOnlyAfterFirstBuffer`; source caps recovery at one | Inject/observe a real live stall |
| Fresh stream does not recover at threshold | **Proven — deterministic** | `testFreshStreamDoesNotRecoverAtThreshold` | None at policy layer |
| Default output change requests recovery before first buffer | **Proven — deterministic** | `testOutputDeviceChangeRecoversEvenBeforeFirstBuffer`; generation-owned listener in capture source | Built-in/AirPods/Bluetooth/output-device hardware matrix |
| Sleep/wake resumes only an active session | **Proven — deterministic policy** | `SaidStatusTextTests.testOnlyActiveCaptureStatesResumeAfterSystemWake`; AppController lifecycle source | Real sleep/wake while captioning |
| Stale callbacks cannot revive stopped capture | **Proven — deterministic ownership** | Production Core Audio callback acceptance uses `OperationEpoch`; `OperationEpochTests.testStopInvalidatesLateStartAndBufferCallbacks` creates an owned callback generation, invalidates it, and proves that same production gate rejects it in a live state | Hardware race stress remains part of broader capture acceptance |
| Rapid start/stop and stop-during-start | **Partial** | Both model/pipeline continuations and Core Audio callbacks use production generation gates; `OperationEpochTests.testRepeatedRapidStartStopCannotReuseAnOldOwner` proves 1,000 superseded start/stop owners remain rejected | Run rapid live start/stop and stop-during-model-load hardware stress |
| Permission denial and recovery | **Open** | Recovery UI and System Settings action are implemented | Fresh denial, Retry, and settings walkthrough receipt |

## Long-run and performance

| Requirement | State | Evidence | Remaining proof |
| --- | --- | --- | --- |
| Short live continuity and bounded RSS | **Proven — harness validation** | 40-second M5 receipt: 3/3 fresh probes, 0 failures, 850 MiB peak RSS, 3.7 MiB peak growth | Does not count as a release-duration run |
| 30-minute live run | **Open** | Strengthened harness is ready: `./scripts/soak-smoke.sh --minutes 30` | Run with default 30-second probes |
| 60-minute live run | **Open** | Same harness | Run and retain content-free receipt |
| Four-hour live run | **Open** | Same harness | Run and retain content-free receipt |
| Physical M1/16 GB latency and memory | **Open** | Virtual M1 stress proves correctness/memory only; see [`model-spike.md`](model-spike.md) | Physical baseline Mac required |
| Available-Mac first-caption feasibility | **Proven — M5 fixture** | 320 ms configuration: 960 ms speech-to-first-caption proxy, ~872 MB peak RSS | Live display latency and p95 corpus remain open |
| CPU/GPU utilization, power, and thermal state | **Open** | No release-duration physical receipt | Measure 30/60/240-minute runs and representative video |
| Representative accuracy corpus | **Open** | Public-domain JFK smoke fixture matched normalized reference (WER 0%) | Accents, calls, music, crosstalk, numbers, acronyms, quiet/fast speech |

## Privacy and security

| Requirement | State | Evidence | Remaining proof |
| --- | --- | --- | --- |
| No caption-content logging path | **Proven — static** | `privacy-smoke.sh` rejects caption interpolation into `SaidLogger` | Post-quit secret-marker search in unified logs |
| No networking API in capture, ASR, core, or app UI | **Proven — static** | Privacy receipt records `caption_network_api_path_present: false` | Live packet observation while captioning offline |
| No analytics or third-party crash SDK | **Proven — static** | Dependency/source scan in `privacy-smoke.sh` | Re-run for final artifact |
| No audio/transcript-like files in Said storage | **Proven — current storage scan** | Privacy smoke scans Application Support | Post-quit marker test across app-owned writable paths |
| Diagnostics are typed and content-free | **Proven — deterministic** | `SaidDiagnosticsSnapshotTests` and allowlisted snapshot type | Manual exported/copied report review if export is added |
| Model replacement/partial-install threats | **Proven — deterministic** | Model manager/downloader tests; exact manifest and atomic install | None at this layer |
| Own process audio excluded | **Proven — source contract** | Private Core Audio tap excludes Said’s process object | Live feedback/recapture regression observation |
| Runtime offline-network observation | **Proven — sampled M5 observation** | `offline-smoke.sh`: four-per-second `lsof` from process identification/model load plus overlapping one-second `nettop` across playback, caption revision, and quiet window; content-free receipt | Repeat for final artifact; this does not claim kernel-level packet interception |
| Post-quit content marker | **Proven — sampled M5 observation** | `post-quit-privacy-smoke.sh`: controlled fixture produced a fresh caption revision; after process termination, fixture words were absent from the Said log interval, preferences, and app-owned writable files; no content-like file remained | Repeat against final artifact; this does not claim physical memory/swap erasure |

## Product and distribution

| Requirement | State | Evidence | Remaining proof |
| --- | --- | --- | --- |
| Native menu-bar app and floating two-line panel | **Proven — current Mac** | Local alpha is playable; capture smoke reaches visible pipeline | Clean-user usability recording and multi-display/full-screen matrix |
| Text appearance, persistent enabled-session surface, hover/menu placement, direct resizing, contrast/transparency/motion behavior | **Partial** | Implemented in SwiftUI/AppKit; deterministic status/mode/size/font/color/layout tests; focused visual comparison in [`design-qa.md`](../design-qa.md); ready/live surface and hover reveal exercised in the running app with owner confirmation | VoiceOver, multi-display, and full accessibility acceptance matrix |
| One-action first-run setup | **Partial** | Setup/model/capture flow implemented and used on development Mac | Clean-user walkthrough without Terminal |
| Local-alpha app and DMG verification | **Proven — local only** | `verify-release.sh`; local DMG SHA-256 `2524381508409411159ed6a8a52cb7aa9ed1e9f8b5ac1505a875d5fbafb823c0` | Ad-hoc artifacts are intentionally not distributable |
| Pinned runtime bootstrap is reproducible | **Proven — deterministic** | `bootstrap.sh` consumes `Dependencies/transcribe-cpp.lock.json`, verifies macOS/Xcode/Swift prerequisites, exact submodule commit, cached archive size/SHA-256, and extracted macOS runtime binary size/SHA-256; every GitHub Quality run executes it from a clean checkout | Continue to update the lock and both artifact receipts together for runtime changes |
| GitHub quality gate | **Proven** | [main run 32592562006](https://github.com/r3dbars/said/actions/runs/32592562006): tests, privacy, bootstrap, app build, package verification, model absence | Keep green for every merge |
| Developer ID signature and Hardened Runtime | **Blocked** | No trusted Developer ID Application identity is installed | Owner must install/provide release identity |
| Notarized and stapled DMG | **Blocked** | Scripts support `notarytool` and stapler; no credentials are configured | Developer ID identity plus notary profile |
| Clean-machine installation | **Open** | Local DMG structure verifies | Test final notarized artifact on Mac without developer tools |
| Model/conversion license review | **Blocked** | Governing NVIDIA license archived; discrepancy documented in [`model-provenance.md`](model-provenance.md) | Explicit human legal review before public distribution |

## Ordered remaining release gates

1. Run the 30-, 60-, and 240-minute live soaks with default probe cadence.
2. Repeat the sampled offline-network and post-quit privacy smokes against the
   final signed artifact.
3. Exercise fresh permission denial/recovery, output-route changes, sleep/wake,
   multi-display/full-screen behavior, and the common-app matrix.
4. Complete screenshot, VoiceOver, contrast, transparency, motion, and clean-user
   onboarding acceptance.
5. Run representative accuracy, live-display latency, power, thermal, and memory
   measurements on a physical M1/16 GB Mac.
6. Obtain explicit human review of the model/conversion license chain.
7. Install a Developer ID Application identity, notarize/staple the DMG, and
   verify it on a clean Mac without developer tools.

Said is a playable local alpha. This matrix must not be used to describe it as
a completed or publicly distributable V1 until every **Open** and **Blocked**
release requirement above is resolved with evidence at the required scope.
