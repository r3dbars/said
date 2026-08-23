#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
lock_file="$repo_root/Dependencies/transcribe-cpp.lock.json"
framework_dir="$repo_root/Dependencies/transcribe.cpp/bindings/swift/build-apple"
framework_path="$framework_dir/TranscribeCpp.xcframework"
archive_path="$repo_root/Artifacts/TranscribeCpp.xcframework.zip"

read_lock() {
  plutil -extract "$1" raw "$lock_file"
}

verify_file() {
  local file_path=$1
  local expected_size=$2
  local expected_sha=$3
  local label=$4
  [[ -f "$file_path" ]] || {
    print -u2 "$label is missing: $file_path"
    return 1
  }
  local actual_size=$(stat -f '%z' "$file_path")
  [[ "$actual_size" == "$expected_size" ]] || {
    print -u2 "$label size mismatch: $actual_size; expected $expected_size"
    return 1
  }
  local actual_sha=$(shasum -a 256 "$file_path" | awk '{print $1}')
  [[ "$actual_sha" == "$expected_sha" ]] || {
    print -u2 "$label SHA-256 mismatch: $actual_sha"
    return 1
  }
}

if [[ "$(uname -m)" != arm64 ]]; then
  print -u2 "Said requires Apple silicon."
  exit 1
fi

macos_version=$(sw_vers -productVersion)
macos_major=${macos_version%%.*}
(( macos_major >= 26 )) || {
  print -u2 "Said requires macOS 26 or later; found $macos_version"
  exit 1
}

# Let each producer drain completely under pipefail. Early-exit consumers can
# otherwise turn a successful version check into SIGPIPE (exit 141) in CI.
xcode_version=$(xcodebuild -version | awk '/^Xcode / && !found { print $2; found=1 }')
xcode_major=${xcode_version%%.*}
(( xcode_major >= 26 )) || {
  print -u2 "Said requires Xcode 26 or later; found $xcode_version"
  exit 1
}

swift_version=$(swift --version 2>&1 | awk '
  match($0, /Swift version [0-9]+/) && !found {
    value=substr($0, RSTART + 14, RLENGTH - 14)
    print value
    found=1
  }
')
[[ -n "$swift_version" ]] || {
  print -u2 "Could not determine the installed Swift version"
  exit 1
}
(( swift_version >= 6 )) || {
  print -u2 "Said requires Swift 6 or later"
  exit 1
}

[[ -f "$lock_file" ]] || {
  print -u2 "Missing runtime lock: $lock_file"
  exit 1
}
lock_commit=$(read_lock commit)
framework_url=$(read_lock artifact_url)
framework_size=$(read_lock artifact_size_bytes)
framework_sha=$(read_lock sha256)
binary_relative_path=$(read_lock macos_binary)
binary_size=$(read_lock macos_binary_size_bytes)
binary_sha=$(read_lock macos_binary_sha256)

git -C "$repo_root" submodule update --init --recursive
actual_commit=$(git -C "$repo_root/Dependencies/transcribe.cpp" rev-parse HEAD)
if [[ "$actual_commit" != "$lock_commit" ]]; then
  print -u2 "transcribe.cpp is $actual_commit; expected $lock_commit"
  exit 1
fi

mkdir -p "$repo_root/Artifacts" "$framework_dir"
if [[ -f "$archive_path" ]]; then
  verify_file "$archive_path" "$framework_size" "$framework_sha" "XCFramework archive"
fi
if [[ ! -d "$framework_path" ]]; then
  if [[ ! -f "$archive_path" ]]; then
    curl -L --fail --output "$archive_path.partial" "$framework_url"
    verify_file \
      "$archive_path.partial" \
      "$framework_size" \
      "$framework_sha" \
      "Downloaded XCFramework archive"
    mv "$archive_path.partial" "$archive_path"
  fi
  unzip -q "$archive_path" -d "$framework_dir"
fi
verify_file \
  "$framework_path/$binary_relative_path" \
  "$binary_size" \
  "$binary_sha" \
  "Extracted macOS runtime binary"

print "Said PR 0 dependencies are ready."
print "Verified macOS $macos_version, Xcode $xcode_version, Swift $swift_version, and pinned native runtime."
print "Run scripts/download-model.sh to install the pinned 731 MB model."
