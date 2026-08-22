#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
lock_commit=ea077b87590bcfb090d7c38c03ab36cd1c7005d3
framework_url=https://github.com/handy-computer/transcribe.cpp/releases/download/v0.2.1/TranscribeCpp.xcframework.zip
framework_sha=d24e6c0aaff1e628a626f792f74bb7155287a49a5c5bb1179deb73b35f0410f5
framework_dir="$repo_root/Dependencies/transcribe.cpp/bindings/swift/build-apple"
framework_path="$framework_dir/TranscribeCpp.xcframework"
archive_path="$repo_root/Artifacts/TranscribeCpp.xcframework.zip"

if [[ "$(uname -m)" != arm64 ]]; then
  print -u2 "Said requires Apple silicon."
  exit 1
fi

git -C "$repo_root" submodule update --init --recursive
actual_commit=$(git -C "$repo_root/Dependencies/transcribe.cpp" rev-parse HEAD)
if [[ "$actual_commit" != "$lock_commit" ]]; then
  print -u2 "transcribe.cpp is $actual_commit; expected $lock_commit"
  exit 1
fi

mkdir -p "$repo_root/Artifacts" "$framework_dir"
if [[ ! -d "$framework_path" ]]; then
  curl -L --fail --output "$archive_path.partial" "$framework_url"
  actual_sha=$(shasum -a 256 "$archive_path.partial" | awk '{print $1}')
  if [[ "$actual_sha" != "$framework_sha" ]]; then
    print -u2 "XCFramework SHA-256 mismatch: $actual_sha"
    exit 1
  fi
  mv "$archive_path.partial" "$archive_path"
  unzip -q "$archive_path" -d "$framework_dir"
fi

print "Said PR 0 dependencies are ready."
print "Run scripts/download-model.sh to install the pinned 731 MB model."
