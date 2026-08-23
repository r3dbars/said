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
| Capture API | Core Audio process tap; System Audio Recording Only permission |
| Microphone / pixels | Never captured |
| Model | Parakeet Unified EN 0.6B, Q8_0 first |
| Runtime | `transcribe.cpp` Swift bindings with Metal |
| Initial stream | left/chunk/right = 5600/160/160 ms |
| Accounts / billing | None in V1 |
| Cloud / fallbacks | None; no Apple Speech, Whisper, or Nemotron |
| Content retention | No audio files, transcripts, history, save, or export |
| Controls | One persistent native menu-bar Said switch; no rewind or session controls |
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

Launch as a menu-bar utility, validate the model, and start capture when the
saved Said switch is enabled. Keep the caption panel visible for the
entire enabled session, including silence between speakers.

### Menu

1. Disabled local status row.
2. Native **Said** switch.
3. **Customize Captions…**
4. **Settings…**
5. **Privacy…**
6. **Quit Said**

Turning captions off immediately hides the panel, stops system-audio capture,
and clears ephemeral caption state. Turning captions on restarts the existing
local pipeline and presents the caption panel immediately when the model is
ready. The off state persists across launches and must be unmistakable:
the status row reads **Captions are off**, the switch is off, and the
menu-bar icon uses its unfilled treatment.

### Caption panel

Use a borderless, nonactivating, click-through `NSPanel` at floating level. It
joins all Spaces, works over full-screen apps, avoids normal window cycling,
and never steals focus. Hovering a visible caption strip reveals its controls
and temporarily makes it draggable; moving away restores click-through
behavior. Explicit placement remains available from the menu bar when no
caption strip is visible.

Default placement is horizontally centered roughly 64 points above the active
display's visible bottom. Persist normalized display-relative placement, the
chosen display when it remains connected, and the user's caption scale.

The panel has five paired caption-scale presets. XS through XL use approximately
14/360, 22/520, 34/760, 44/1000, and 56/1280 point text/width combinations,
with width clamped to no more than about 90% of the active display. The pairings
keep roughly six or seven words on each line instead of allowing type and window
proportions to drift independently. Use 24-point horizontal and 17–20-point
vertical padding, and about a 20–22-point radius. Use a dark neutral rounded
surface, near-white text, and a subtle highlight border without a broad shadow
or rectangular material-compositing region. Use an opaque high-contrast fallback
for Reduce Transparency or Increase Contrast.

Typography starts at 34 pt medium/semibold with Small 26 pt and Large 44 pt.
Committed text is full opacity. Tentative text uses the same type at roughly
58–68% opacity. No italics, speaker labels, timestamps, icons, waveforms,
colored hypotheses, springs, or per-character animation.

The hover/placement caption-control bar offers three intentionally small appearance
sets: one XS–XL Caption Size control that changes type and panel geometry together,
Rounded/Sans/Serif/Mono/Block system fonts, and White/Warm Yellow/Cyan text. Size and font
changes are one-click cycles; color swatches are direct one-click choices.
Tentative text uses the selected color at reduced opacity rather than a different
semantic hue. All choices persist as ordinary app settings.

While the Said switch is enabled, keep the panel visible and preserve the latest
caption between utterances. Before the first caption, show one quiet secondary
status such as **Waiting for speech…**. Starting, recovery, and failure states
may replace that placeholder with equally short human copy. Do not fade or hide
the panel because of silence. Turning Captions Off is the only normal action
that removes the surface and clears its ephemeral text.

Pack caption words forward into two explicit, stable one-line rows. The active
row grows along the bottom. When the next row begins, the completed lower row
advances upward as one unit instead of reflowing on every new word. Keep only
the newest two rows, tune row capacity for each text size, and use a leading
ellipsis only when an older row has been discarded. Never add marquee motion,
continuous pixel scrolling, or a history drawer.

### Move, settings, privacy

Hovering visible captions makes the whole panel draggable and adds a compact
dark control bar outside—not inside—the caption surface. Its controls form one
left-aligned cluster. Clicking the visible XS, S, M, L, or XL Caption Size value
cycles the five paired text/window presets. The control also shows the active
point size so its effect remains legible. Font and color remain direct compact controls.
The bar collapses shortly after
the pointer leaves and captions return to click-through behavior. The menu-bar
Customize Captions mode remains available during silence, shows a sample, and adds
an explicit Done control. Scale changes snap immediately, remain centered when
space allows, persist across launches, and clamp to the product/display bounds.
When the panel moves into
the upper half of its display, place the toolbar below the caption card; place
it above the card in the lower half. Settings contains caption
size, Reset Caption Layout, native
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
menu bar and `NSPanel`, a private Core Audio process tap, native
AVFoundation/Accelerate conversion, pinned `TranscribeCpp`, Metal, CryptoKit,
content-free OSLog, and `SMAppService`.

Pipeline:

```text
Mac app audio
  -> private Core Audio process tap
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

Adapt, do not wholesale copy, the proven Core Audio process-tap path in
`r3dbars/transcripted/Sources/TranscriptedCore/Audio/SystemAudioCapture.swift`,
`SystemAudioProcessTap.swift`, and their supporting utilities.

Use a private `CATapDescription` global stereo tap that excludes Said's own
process, feed it through a private aggregate device, and request only
`NSAudioCaptureUsageDescription`. This must place Said under macOS's **System
Audio Recording Only** permission category. Never include a screen-capture
usage description or create a ScreenCaptureKit stream. Own buffer memory before
asynchronous dispatch. Core Audio process taps may emit no callbacks while the
Mac is silent, so successful tap/device startup establishes readiness and the
first nonempty callback proves the data path once playback begins. Never report
silence alone as a start failure.

Port generation/epoch ownership, explicit phases, one recovery claim, and a
3–5 second post-first-buffer watchdog. Invalidate stale callbacks, reconstruct
the tap after an output-device change, and never loop recovery forever or treat
amplitude silence as a stall.

`Info.plist` includes system/audio capture explanations and deliberately omits
both `NSMicrophoneUsageDescription` and `NSScreenCaptureUsageDescription`.

### Owner correction — August 22, 2026

The initial build used an audio-output-only ScreenCaptureKit stream, but macOS
listed Said under **Screen & System Audio Recording** on the owner's machine.
The owner required Said to appear under **System Audio Recording Only**. The
capture backend was therefore changed to Core Audio process taps. This explicit
owner decision supersedes the earlier ScreenCaptureKit lock in the original
draft PRD while preserving the stronger invariant: Said has no screen-pixel
capture path at all.

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

## Development decision addendum

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-08-22 | Proceed with a local alpha on the available M5 Max | The virtual M1 run proved correctness and memory safety but its three-core paravirtual environment is not representative of physical-M1 real-time performance. A physical M1/16 GB receipt remains a public-release gate. |
| 2026-08-22 | Roll captions in stable whole-line steps | A moving suffix caused the upper line to rewrap under the reader's eyes. The lower row now grows in place and advances upward only when a new row begins. |
| 2026-08-22 | Hover visible captions to adjust them; retain explicit menu placement | Hover removes unnecessary menu-bar friction while delayed collapse restores normal click-through behavior. The menu action remains the dependable path during silence and shows an explicit Done affordance. |
| 2026-08-22 | Put a compact appearance bar above captions during layout editing | The owner selected a dense dark-toolbar reference and requested one-click size and color plus a few font choices without adding persistent normal-mode chrome. |
| 2026-08-22 | Add a persistent menu-bar Captions On toggle | People need an unmistakable indication of when captions should appear. Off stops capture, clears the panel, and persists across relaunches; the checkmark, status copy, and icon treatment all expose the state. |
| 2026-08-22 | Replace freeform width dragging with XS–XL width steps | The narrow drag target was hard to acquire and produced unpredictable sizing. A bounded click control is easier to understand, accessible from hover or menu customization, and persists deterministically. |
| 2026-08-22 | Make size labels cycle directly and flip the toolbar by vertical position | Removing arrow targets makes sizing behave like the compact reference toolbar. Keeping controls left-aligned reduces eye travel, while moving the toolbar below top-positioned captions prevents it from obstructing or being pushed off-screen. |
| 2026-08-22 | Combine text and window size into one XS–XL Caption Size setting | Independent size controls allowed awkward combinations and added unnecessary choice. Five balanced presets preserve the useful physical range, keep line length consistent, and make the toolbar shorter and easier to understand. |
| 2026-08-22 | Add Mono and Block caption faces | A five-style system-font set adds genuinely different reading treatments without introducing font installation, arbitrary pickers, or non-native dependencies. |
| 2026-08-22 | Keep the caption panel visible while Captions On | Said is a deliberate call/video mode rather than an all-day ambient overlay. A persistent surface makes the on/off state predictable, preserves the reader's visual anchor between speakers, and disappears only when the user turns captions off. |
| 2026-08-23 | Use a native Said switch at the top of the menu | A bold product header plus a switch communicates the persistent on/off state more immediately than a checked command item. A restrained status indicator remains directly below it so control and operational truth stay distinct. |

## Definition of done

Said V1 is done only when a nondeveloper can install a signed/notarized/stapled
DMG, complete one-action setup, play spoken English, read stable two-line
captions without focus theft, quit cleanly, and all audio, model, caption,
privacy, performance, long-run, licensing, and clean-machine gates above pass.

The bar is not that a model returned text. The bar is a quiet Mac utility whose
permission makes sense, captions appear quickly and remain calm, nothing is
uploaded or accumulated, and quitting ends the experience completely.
