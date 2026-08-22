# Privacy contract

Said turns Mac playback into captions without creating a recording or a
transcript. Audio samples and caption hypotheses exist temporarily in process
memory while Said is open. Said releases its app-owned buffers when the stream
resets and when the app quits; it does not claim cryptographic memory erasure or
control over macOS swap behavior.

## What Said accesses

- Audio that macOS exposes through a private Core Audio process tap.
- The pinned English speech-model file in Said's Application Support folder.
- Said's own preferences, model receipt, and update metadata when updates are
  added.

While a caption strip is visible, Said compares the current pointer location
to the strip's bounds so hovering can reveal its controls. Pointer locations
are not logged, saved, transmitted, or used outside that interaction.

## What Said does not access

- Microphone or camera.
- Screen pixels.
- Keyboard or clipboard.
- User documents, browser history, window titles, or URLs.

## Persistence

Said may persist only the verified model, its content-free receipt, and normal
application preferences. The application does not write PCM, audio containers,
caption text, or transcript files. Removing the local model returns Said to
setup.

## Network boundary

The production model manager may connect only to the immutable pinned model URL
while installing or reinstalling the model. Caption inference has no network
code path. A future updater may check signed releases, but update failure must
never affect captions and no audio, caption, application, or user identifiers
may be included.

## Diagnostics

Local unified logs contain only allowlisted operational measurements: state,
safe error codes, sample rate/channel count, counts, revisions, durations, and
the pinned model identity. They never contain audio samples, caption text,
hypotheses, application names, window titles, URLs, or user paths.

Run `./scripts/privacy-smoke.sh` to enforce the static permission, dependency,
logging, caption-path networking, binary-string, and app-storage boundaries.
A successful run writes a content-free JSON receipt under
`Artifacts/Receipts/Privacy/`; the receipt explicitly records that it is a
static check and not a runtime network observation. The live offline-network
check runs separately with `./scripts/offline-smoke.sh`. It polls Said's
Internet sockets four times per second with `lsof` beginning immediately after
process identification, including local model load. After the model is ready,
`nettop` observes the process once per second across playback, a real caption
revision, and a quiet post-caption window. The tools overlap live inference.
Raw observations are discarded; the content-free receipt is written under
`Artifacts/Receipts/Offline/`. This is direct sampled socket observation, not a
claim of kernel-level packet interception.

`./scripts/post-quit-privacy-smoke.sh` exercises the separate retention gate. It
plays a controlled, non-user fixture, requires a fresh caption revision, quits
Said, confirms the process has terminated, and searches the Said unified-log
interval, preferences, and app-owned writable locations for each distinctive
fixture word. It also checks for audio- or transcript-like files. The fixture,
caption text, and raw observations are excluded from the content-free receipt
and removed when the test exits. This proves the inspected app-owned and logging
boundaries; it does not claim cryptographic erasure of process memory or
operating-system swap.
