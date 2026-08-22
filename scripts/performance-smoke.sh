#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
receipt_dir="$repo_root/Artifacts/Receipts/PR0"
binary="$repo_root/.build/release/said-model-spike"

cd "$repo_root"
swift build -c release
mkdir -p "$receipt_dir"

run_case() {
  local name=$1
  local left_ms=$2
  local chunk_ms=$3
  local right_ms=$4
  local feed_ms=$5
  local raw="$receipt_dir/$name.raw.json"
  local log="$receipt_dir/$name.log"
  local summary="$receipt_dir/$name.summary.json"

  /usr/bin/time -l "$binary" \
    --left-ms "$left_ms" \
    --chunk-ms "$chunk_ms" \
    --right-ms "$right_ms" \
    --feed-ms "$feed_ms" \
    >"$raw" 2>"$log"

  local peak_rss
  peak_rss=$(awk '/maximum resident set size/ {print $1; exit}' "$log")
  jq --arg name "$name" --argjson peak_rss "${peak_rss:-0}" \
    'del(.feedReceipts) + {name: $name, peakResidentBytes: $peak_rss}' \
    "$raw" >"$summary"
}

# Warm Metal shader and filesystem caches; this result is deliberately discarded.
"$binary" >/dev/null 2>"$receipt_dir/warmup.log"

# Lookahead comparison. Feed blocks remain at 160 ms except where a runtime
# configuration requires an 80 ms chunk.
run_case lookahead-160 5600 80 80 80
run_case lookahead-320 5600 160 160 160
run_case lookahead-480 5600 160 320 160
run_case lookahead-1120 5600 560 560 160

# Feed-block comparison at the locked 5600/160/160 tuple.
run_case feed-80 5600 160 160 80
run_case feed-160 5600 160 160 160
run_case feed-320 5600 160 160 320

jq -s '.' "$receipt_dir"/*.summary.json >"$receipt_dir/matrix.json"
print "PR 0 performance matrix: $receipt_dir/matrix.json"
jq '[.[] | {
  name,
  lookaheadMilliseconds: (.chunkMilliseconds + .rightMilliseconds),
  feedBlockMilliseconds,
  modelLoadMilliseconds,
  speechToFirstCaptionMilliseconds,
  feedWallP50Milliseconds,
  feedWallP95Milliseconds,
  feedWallP99Milliseconds,
  totalFeedWallMilliseconds,
  committedMutationCount,
  displayDivergenceCount,
  tentativeEverNonempty,
  peakResidentBytes
}]' "$receipt_dir/matrix.json"
