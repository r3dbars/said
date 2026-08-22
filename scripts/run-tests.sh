#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
cd "$repo_root"

swift test
"$repo_root/scripts/privacy-smoke.sh"
