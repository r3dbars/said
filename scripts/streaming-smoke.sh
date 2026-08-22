#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
cd "$repo_root"
swift run -c release said-model-spike --show-text "$@"
