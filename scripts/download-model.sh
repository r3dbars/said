#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
model_url=https://huggingface.co/handy-computer/parakeet-unified-en-0.6b-gguf/resolve/7e948f21b7bdbac698d3318db9d350f1096f3b6c/parakeet-unified-en-0.6b-Q8_0.gguf
model_sha=4b50b6dd862bf6e346929aaf4f5eaacec003bfa3f56462d6c874b41ef2f38795
model_size=731357568
model_dir="$repo_root/Artifacts/Models"
model_path="$model_dir/parakeet-unified-en-0.6b-Q8_0.gguf"
partial_path="$model_path.partial"

mkdir -p "$model_dir"
if [[ -f "$model_path" ]]; then
  actual_size=$(stat -f %z "$model_path")
  actual_sha=$(shasum -a 256 "$model_path" | awk '{print $1}')
  if [[ "$actual_size" == "$model_size" && "$actual_sha" == "$model_sha" ]]; then
    print "Pinned Said speech model is already verified."
    exit 0
  fi
  print -u2 "Existing model is invalid; refusing to overwrite it automatically."
  exit 1
fi

curl -L --fail --continue-at - --output "$partial_path" "$model_url"
actual_size=$(stat -f %z "$partial_path")
[[ "$actual_size" == "$model_size" ]] || { print -u2 "Model size mismatch: $actual_size"; exit 1; }
actual_sha=$(shasum -a 256 "$partial_path" | awk '{print $1}')
[[ "$actual_sha" == "$model_sha" ]] || { print -u2 "Model SHA-256 mismatch: $actual_sha"; exit 1; }
mv "$partial_path" "$model_path"
print "Pinned Said speech model installed and verified."
