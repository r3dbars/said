# Model and runtime provenance

## Pinned model

| Field | Value |
| --- | --- |
| Upstream | `nvidia/parakeet-unified-en-0.6b` |
| Conversion | `handy-computer/parakeet-unified-en-0.6b-gguf` |
| Revision | `7e948f21b7bdbac698d3318db9d350f1096f3b6c` |
| File | `parakeet-unified-en-0.6b-Q8_0.gguf` |
| Size | `731357568` bytes |
| SHA-256 | `4b50b6dd862bf6e346929aaf4f5eaacec003bfa3f56462d6c874b41ef2f38795` |

Immutable download URL:

```text
https://huggingface.co/handy-computer/parakeet-unified-en-0.6b-gguf/resolve/7e948f21b7bdbac698d3318db9d350f1096f3b6c/parakeet-unified-en-0.6b-Q8_0.gguf
```

The size and SHA-256 were independently confirmed from the Git LFS pointer at
the pinned conversion revision. The conversion records NVIDIA source revision
`d4ac9928f3bf238223ff0779c06b8149bf8ac4e1`. Handy's catalog was cross-checked
at commit `0e5036721ef6f26c3b89ab31bc10cd2ffd6096fb`.

## Runtime

`handy-computer/transcribe.cpp` is pinned to tag `v0.2.1`, commit
`ea077b87590bcfb090d7c38c03ab36cd1c7005d3`. The official XCFramework asset is
pinned by exact size and SHA-256 in `Dependencies/transcribe-cpp.lock.json`.

## Release blocker

The conversion metadata and Handy catalog label the artifact CC-BY-4.0, while
the pinned and current authoritative NVIDIA model cards place the model under
the NVIDIA Open Model License. Treat the weights as NVIDIA Open Model License
material pending human legal review. If Said distributes weights, it must at
minimum include that license and a NOTICE containing the required NVIDIA
attribution. Public model distribution remains blocked until this discrepancy
and all redistribution obligations receive explicit human review. Do not ship
a CC-BY-only notice.

The repository archives NVIDIA's official October 24, 2025 Open Model License
PDF at `Resources/Licenses/NVIDIA-Open-Model-License-2025-10-24.pdf` with
SHA-256 `4d2fb590aa9b30c47f2058bff17291df7fa2aa0c1bd775a20703da9bb267cfab`.
This preserves the governing text and required attribution while human review
remains outstanding.
