# Threat model

Said processes private system audio and captions transiently. Its smallest
credible privacy boundary is enforced by architecture and tests.

| Threat | Required mitigation |
| --- | --- |
| Replaced/corrupt model | Immutable revision, exact size/SHA, verify before load |
| Partial model accepted | `.partial` path and atomic verified install |
| Stale callback after stop | generation/epoch plus stream identity |
| Duplicate recovery | one lock-owned bounded recovery claim |
| Expired sample memory | owned audio copy before async processing |
| Content in diagnostics | typed allowlisted events, no arbitrary metadata |
| Crash-report leakage | no third-party crash reporter in V1 |
| Microphone capture | no usage string, API path, or permission request |
| Pixel capture | no `.screen` output; code-contract test |
| Said hears itself | `excludesCurrentProcessAudio = true` |
| Captioning network request | offline network smoke with model present |
| Content persistence | privacy marker scan after stop and quit |

Audio and captions may exist in process memory while active. Said releases its
buffers at reset/termination but does not claim cryptographic erasure or control
over macOS swap behavior.

