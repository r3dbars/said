#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
swift "$repo_root/scripts/render-app-icon.swift" "$repo_root/Resources/Said.icns"
print "$repo_root/Resources/Said.icns"
