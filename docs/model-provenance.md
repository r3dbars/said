# Model and runtime provenance

## Model candidate

| Field | Pinned candidate |
| --- | --- |
| Upstream | `nvidia/parakeet-unified-en-0.6b` |
| Conversion | `handy-computer/parakeet-unified-en-0.6b-gguf` |
| Revision | `7e948f21b7bdbac698d3318db9d350f1096f3b6c` |
| File | `parakeet-unified-en-0.6b-Q8_0.gguf` |
| Size | `731357568` bytes |
| SHA-256 | `4b50b6dd862bf6e346929aaf4f5eaacec003bfa3f56462d6c874b41ef2f38795` |

These values came from the owner PRD. PR 0 must independently verify them from
the immutable revision before they become release truth.

## Runtime

`handy-computer/transcribe.cpp` will be pinned only after current Swift APIs,
Apple build instructions, Metal support, buffered-stream extension, and license
files are inspected. The exact source commit and XCFramework SHA belong in
`Dependencies/transcribe-cpp.lock.json`.

## Release blocker

Catalog/conversion material and the upstream NVIDIA model card may name
different licenses. Preserve the exact pinned model card, conversion notices,
runtime notices, and conversion chain. Human license review is required before
public binary distribution. Do not infer a model license from a catalog label.

