# Said

## Product Requirements Document and Agent Build Guide

**Version:** 0.1  
**Date:** August 22, 2026  
**Status:** Build-ready  
**Owner:** Justin Betker  
**Product name:** Said  
**Historical working name:** Listen  
**Product rule:** **Hear. Read. Gone.**

This repository uses **Said** as the product, executable, package, repository,
and user-facing name. Historical anchors may use Listen. Every other product
decision in the owner's August 22 PRD remains unchanged.

## Product contract

Said is a native Mac utility that turns audio playing through the Mac into
beautiful live captions, entirely on-device.

The whole experience is:

1. Install and open Said.
2. Allow system-audio access.
3. Wait once for the local English model to download and verify.
4. Play spoken English in any Mac app.
5. Read captions in a calm floating two-line panel.
6. Quit Said; captions disappear.

**Promise:** Live captions for anything your Mac plays. Nothing is uploaded.
Nothing is kept.

**Job:** When spoken audio playing through the Mac is difficult to hear or
understand, provide readable captions immediately without a bot, upload,
account, recording, or permanent transcript.

## Principles

1. One job: caption Mac system audio.
2. No named, saved, resumed, or deleted sessions.
3. No recordings or transcripts for the user to manage.
4. Audio and captions stay in process memory and are never app-persisted.
5. Stable captions beat frantic low-latency rewriting.
6. One model, one language, one style, one flow.
7. Native Swift/AppKit/SwiftUI only; no browser shell or helper service.

## **LOCKED** V1 decisions

| Area | Decision |
| --- | --- |
| Platform | Native macOS 26+ |
| Hardware | Apple silicon, M1 or newer |
| Language | English only |
| Audio | Mac system audio only |
| Microphone / pixels | Never captured |
| Model | Parakeet Unified EN 0.6B, Q8_0 first |
| Runtime | `transcribe.cpp` Swift bindings with Metal |
| Initial stream | left/chunk/right = 5600/160/160 ms |
| Accounts / billing | None in V1 |
| Cloud / fallbacks | None; no Apple Speech, Whisper, or Nemotron |
| Content retention | No audio files, transcripts, history, save, or export |
| Controls | No Pause, Rewind, or normal-use Start/Stop |
| Expansion | No translation, summaries, labels, detection, or model picker |
| Data services | No analytics or third-party crash reporting |
| Distribution | Direct signed and notarized Mac app; no App Store V1 |

Do not create abstractions, hidden preferences, hooks, or empty UI for V2.

## Audience and supported moments

Primary users include people with hearing difficulty, people in noisy or quiet
environments, second-language English listeners, knowledge workers, and
privacy-sensitive users. Said should caption calls, webinars, browser videos,
podcasts, voice messages, training material, interviews, screen recordings,
native media, and enterprise apps where macOS exposes the audio stream.

Said does not capture the local microphone. In calls, remote participants are
generally in system playback; the local user's voice may not be. Copy must say
this honestly.

## Required V1 experience

### First launch

Show one small native window titled **Set up Said**.

- Headline: **Live captions for anything your Mac plays.**
- Support: **Audio stays on this Mac. Captions disappear when Said quits.**
- System Audio row: permission state and plain audio-only explanation.
- Speech Model row: download, bytes, verification, ready, and recovery states.
- One primary action: **Set Up Said**; when ready, **Start Captions**.

Never request microphone, Accessibility, Full Disk Access, clipboard, camera,
or account access. Never show technical model or language choices. Partial
downloads resume safely. Denied permission offers System Settings and Retry.

### Later launches

Launch as a menu-bar utility, validate and load the model, start capture, and
remain hidden until speech produces text. There is no normal-use Start button.

### Menu

1. Disabled local status row.
2. **Move Captions…**
3. **Settings…**
4. **Privacy…**
5. **Quit Said**

There is no Pause or Stop item. Quitting stops the product.

### Caption panel

Use a borderless, nonactivating, click-through `NSPanel` at floating level. It
joins all Spaces, works over full-screen apps, avoids normal window cycling,
never steals focus, and becomes draggable only in explicit placement mode.

Default placement is horizontally centered roughly 64 points above the active
display's visible bottom. Persist normalized display-relative placement.

The panel has a fixed two-line height, default width near 760 points (440–980,
never above about 72% of display width), 24-point horizontal and 17–20-point
vertical padding, and about a 20–22-point radius. Use a dark neutral native
material, near-white text, subtle border/shadow, and an opaque high-contrast
fallback for Reduce Transparency or Increase Contrast.

Typography starts at 34 pt medium/semibold with Small 26 pt and Large 44 pt.
Committed text is full opacity. Tentative text uses the same type at roughly
58–68% opacity. No italics, speaker labels, timestamps, icons, waveforms,
colored hypotheses, springs, or per-character animation.

Show on first text. Hold 1.8 seconds after final revision, then fade over about
180 ms; cancel a fade immediately when new text arrives. Respect Reduce Motion.

Window visible text to roughly the newest 22–28 words, preferring a sentence
boundary, and use a leading ellipsis only when useful. Never add scrolling or a
history drawer.

### Move, settings, privacy

Move mode shows a sample, temporary drag interaction, short instruction, Done,
and Reset Position. Settings contains caption size, reset position, native
launch-at-login via `SMAppService`, model storage/reinstall/reveal, version,
licenses, privacy, support, and updates. Do not expose runtime internals.

Privacy copy must distinguish temporary in-memory processing from persistence:
Said hears Mac playback while open; it does not capture microphone, camera,
pixels, keyboard, clipboard, files, or browser history. Only model download and
signed update checks may use the network. Only model bytes and settings persist.

### Errors

Use explicit unsupported-Mac, permission, download, verification, model/Metal,
and capture-lost failures with one clear recovery action. Capture and ASR each
get one bounded automatic recovery attempt. Never fail over silently.

## Architecture

Use Swift 6, SwiftUI for setup/settings/caption content, AppKit for lifecycle,
menu bar and `NSPanel`, ScreenCaptureKit audio-only capture, native
AVFoundation/Accelerate conversion, pinned `TranscribeCpp`, Metal, CryptoKit,
content-free OSLog, and `SMAppService`.

Pipeline:

```text
Mac app audio
  -> audio-only ScreenCaptureKit stream
  -> owned 48 kHz stereo AVAudioPCMBuffer
  -> serial normalization queue
  -> 16 kHz mono Float32
  -> 160 ms / 2,560-sample blocks
  -> ParakeetUnifiedASR actor
  -> transcribe.cpp Stream.feed
  -> committed + tentative StreamText
  -> CaptionReducer
  -> MainActor CaptionPanelController
```

Capture callbacks only validate generation, record receipt time, copy owned
audio, and enqueue normalization. They never infer, touch UI, perform file I/O,
log content, wait on the main actor, or block on model locks. A serial
high-priority queue normalizes. An actor exclusively owns model, session,
stream, revision, recovery, and safe counters. UI state remains on MainActor.

Use explicit `ListenState`-equivalent product state named for Said, plus capture
and ASR enums. Do not derive lifecycle from unrelated booleans.

## Capture requirements

Adapt, do not wholesale copy, the hardened path in
`r3dbars/transcripted/Sources/TranscriptedCore/Audio/SCKAudioCapture.swift` and
its tests. Also inspect historical commits `1b3e133f...` and `750b7d4d...`.

Use `SCContentFilter(display:excludingWindows:)`, `capturesAudio = true`,
`excludesCurrentProcessAudio = true`, 48 kHz, two channels, and a minimal 2x2
configuration required by the API. Attach only `.audio`; never `.screen`. Own
buffer memory before asynchronous dispatch. Do not claim capture until a valid
nonempty buffer arrives within five seconds.

Port generation/epoch ownership, phases, callback timeouts, long initial
permission timeout, one recovery claim, 3–5 second post-first-buffer watchdog,
stream identity, stale callback invalidation, sleep/wake, and display
reacquisition. Never loop recovery forever or treat amplitude silence as a
stall.

`Info.plist` includes system/audio capture explanations and deliberately omits
`NSMicrophoneUsageDescription`.

## Audio and ASR requirements

Average channels to mono and resample deterministically to normalized 16 kHz
Float32 off the main actor with bounded storage and format-change resets. Start
with 160 ms blocks and benchmark 80/160/320 independently from model tuple
changes. Do not add aggressive VAD or discard silence.

Model manifest baseline:

```json
{
  "repository": "handy-computer/parakeet-unified-en-0.6b-gguf",
  "revision": "7e948f21b7bdbac698d3318db9d350f1096f3b6c",
  "filename": "parakeet-unified-en-0.6b-Q8_0.gguf",
  "size_bytes": 731357568,
  "sha256": "4b50b6dd862bf6e346929aaf4f5eaacec003bfa3f56462d6c874b41ef2f38795"
}
```

Verify every value independently before use and record the immutable source.
Pin an exact `transcribe.cpp` commit and reproducible XCFramework SHA. Preserve
all notices. Distribution is blocked until the NVIDIA/conversion license-label
inconsistency receives human review.

Start buffered streaming at 5600/160/160 with stable-prefix agreement 3.
Benchmark lookahead configurations 160 (5600/80/80), 320 (5600/160/160), 480
(5600/160/320), and 1120 ms (5600/560/560), plus agreement 2 vs 3. Exclude the
80 ms zero-right-context mode. Committed text is append-only; on violation,
increment a content-free metric, reset, and never rewrite prior committed UI.

## Model installation

Store the final model under `~/Library/Application Support/Said/Models/` and a
`.partial` under `.../Downloads/`. Use HTTPS immutable URLs, resume, exact byte
count, SHA-256, atomic replacement, a receipt after verification, corruption
deletion, and preservation of any previously valid model. Validate the full
hash at every launch until the owner approves a measured optimization.

## Caption invariants

- Committed text appends within a stream.
- Tentative replaces only tentative.
- Identical revisions cause no UI work.
- Whitespace normalization is deterministic.
- App state keeps only the bounded visible suffix.
- Reset clears all content.
- Content never enters logs, filenames, preferences, analytics, or crash data.
- Coalesce visual updates to about 10–15 Hz while delivering the first nonempty
  caption and always retaining the newest snapshot.

Permanent stability metrics are committed mutation count (must be zero),
stable-region edit distance (zero), tentative rewrite span, and revisions per
spoken second.

## Privacy and security

Audio and captions exist temporarily in process memory. Do not claim
cryptographic memory erasure. Production code never persists them. Model
download and optional signed update checks are the only network paths.

OSLog categories are app, capture, audio, model, asr, and ui. Only typed,
content-free allowlisted fields may be emitted: state, timing, counts, formats,
revision/hash prefix, safe errors, and resource metrics. Never emit audio,
hypotheses, app/window/source identity, URLs, usernames, or non-app paths.

Threat tests cover model replacement, partial install, stale capture callbacks,
duplicate recovery, buffer lifetime, diagnostic leakage, microphone/pixel
capture absence, no third-party crash payload, and own-audio exclusion.

## Performance gates

Baseline: M1, 16 GB, current macOS 26 production release.

| Metric | Goal | Release ceiling |
| --- | ---: | ---: |
| Warm launch to listening | 3 s | 5 s |
| Verify + load p95 M1 | 7 s | 10 s |
| Capture to first buffer p95 | 1 s | 2 s |
| Speech onset to first caption p95 | 1.0 s | 1.5 s |
| Word display p95 | 900 ms | 1.5 s |
| ASR snapshot to UI p95 | 50 ms | 100 ms |
| Committed mutations | 0 | 0 |
| Content files / offline requests / 4h crashes | 0 | 0 |

Starting memory target is under 2.0 GB; investigate above 2.3 GB. No continuous
pinning of all performance cores, critical thermal state, unbounded queues,
buffers, history, tasks, revisions, or RSS growth over 30 min, 60 min, and 4 h.

## Evaluation and tests

Use only owned or properly licensed fixtures covering clean, conversational,
compressed, fast/slow, accented, quiet/loud, music, silence, crosstalk, proper
nouns, numbers, dates, acronyms, profanity, punctuation, long speech, and short
utterances. Report WER where possible, latency definitions, revision/churn,
memory/CPU/Metal, load time, thermal state, drops, and feed p50/p95/p99.

Permanent regression evidence includes pure reducer/chunker/manifest/state/
diagnostic tests, real-model integration tests, hardware acceptance passes,
screenshot review, and a privacy marker smoke that proves no content file, log,
or captioning network request.

Hardware-only claims cannot be proven in ordinary CI.

## Pull-request plan

1. **PR 0:** Pin runtime/model, build XCFramework, Swift streaming harness,
   Metal and true-streaming proof, benchmark matrix, `docs/model-spike.md`.
2. **PR 1:** Native menu-bar shell, panel, placement, settings, login item.
3. **PR 2:** Hardened audio-only capture and recovery.
4. **PR 3:** Verified resumable model manager.
5. **PR 4:** Production Parakeet actor and headless pipeline.
6. **PR 5:** Stable reducer and visual/accessibility polish.
7. **PR 6:** One-action onboarding and privacy/recovery experience.
8. **PR 7:** Four-hour reliability, privacy, and performance gates.
9. **PR 8:** signed, notarized, stapled DMG, notices, and update path.

Each PR documents changes, non-changes, user behavior, privacy impact, commands,
tests, manual hardware evidence, performance, unknowns, screenshots when
relevant, and exact dependency pins. Do not proceed past an exit gate merely
because a later layer is easier.

## PR 0 stop conditions

Stop and report rather than violate the product if true Parakeet streaming is
not exposed through Swift, Metal is unreliable, M1 latency misses the release
ceiling, committed text mutates, audio-only capture requires pixels, a forbidden
helper/cloud path is necessary, the license chain blocks distribution, or
long-run memory cannot be bounded.

## Definition of done

Said V1 is done only when a nondeveloper can install a signed/notarized/stapled
DMG, complete one-action setup, play spoken English, read stable two-line
captions without focus theft, quit cleanly, and all audio, model, caption,
privacy, performance, long-run, licensing, and clean-machine gates above pass.

The bar is not that a model returned text. The bar is a quiet Mac utility whose
permission makes sense, captions appear quickly and remain calm, nothing is
uploaded or accumulated, and quitting ends the experience completely.

