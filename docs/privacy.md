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
logging, binary-string, and app-storage boundaries. The live offline-network
and post-quit marker checks remain hardware acceptance gates before release.
