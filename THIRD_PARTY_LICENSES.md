# Third-party notices

Said does not bundle its speech-model weights. On first setup it downloads the
single pinned model artifact directly from its immutable upstream conversion
revision. The app bundle does include the native `transcribe.cpp` runtime.

| Component | Exact source | Governing terms |
| --- | --- | --- |
| `transcribe.cpp` and Swift binding | `handy-computer/transcribe.cpp` commit `ea077b87590bcfb090d7c38c03ab36cd1c7005d3` | MIT |
| ggml | vendored by the pinned `transcribe.cpp` revision | MIT |
| miniz | vendored by the pinned `transcribe.cpp` revision | MIT |
| Parakeet Unified EN 0.6B | `nvidia/parakeet-unified-en-0.6b`, converted by `handy-computer/parakeet-unified-en-0.6b-gguf` revision `7e948f21b7bdbac698d3318db9d350f1096f3b6c` | NVIDIA Open Model License |

The packaged application includes verbatim runtime and dependency license
files from the pinned source tree plus NVIDIA's official October 24, 2025 Open
Model License PDF. Model licensing and provenance remain a human-reviewed
public-release gate; see `docs/model-provenance.md`.
