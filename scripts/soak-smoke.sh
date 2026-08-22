#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
app="$repo_root/dist/Said.app"
duration_seconds=1800
sample_interval_seconds=5
maximum_rss_growth_kb=$((256 * 1024))

while (( $# > 0 )); do
  case "$1" in
    --minutes)
      [[ ${2:-} == <-> ]] || { print -u2 "--minutes requires a whole number"; exit 2; }
      duration_seconds=$(( $2 * 60 ))
      shift 2
      ;;
    --seconds)
      [[ ${2:-} == <-> ]] || { print -u2 "--seconds requires a whole number"; exit 2; }
      duration_seconds=$2
      shift 2
      ;;
    *)
      print -u2 "usage: $0 [--minutes WHOLE_NUMBER | --seconds WHOLE_NUMBER]"
      exit 2
      ;;
  esac
done

(( duration_seconds > 0 )) || { print -u2 "duration must be greater than zero"; exit 2; }
[[ -d "$app" ]] || {
  print -u2 "Build Said first with ./scripts/build-and-run.sh --verify"
  exit 1
}

receipt_dir="$repo_root/Artifacts/Receipts/Soak"
run_id=$(/bin/date -u '+%Y%m%dT%H%M%SZ')
receipt="$receipt_dir/soak-$run_id.json"
log_file=$(/usr/bin/mktemp /private/tmp/said-soak-log.XXXXXX)
rss_file=$(/usr/bin/mktemp /private/tmp/said-soak-rss.XXXXXX)
log_pid=""

cleanup() {
  if [[ -n "$log_pid" ]]; then
    /bin/kill "$log_pid" 2>/dev/null || true
    wait "$log_pid" 2>/dev/null || true
  fi
  /bin/rm -f "$log_file" "$rss_file"
}
trap cleanup EXIT

wait_for_log() {
  local pattern=$1
  local timeout_seconds=$2
  local waited=0
  while (( waited < timeout_seconds )); do
    /usr/bin/grep -q "$pattern" "$log_file" && return 0
    /bin/sleep 1
    (( waited += 1 ))
  done
  return 1
}

failure_pattern='Audio block queue overflowed|failed after bounded recovery|System-audio capture failed|Caption pipeline failed|startTimedOut'

/usr/bin/osascript -e 'tell application "Said" to quit' 2>/dev/null || true
for _ in {1..50}; do
  if ! /usr/bin/pgrep -f "$app/Contents/MacOS/Said" >/dev/null; then
    break
  fi
  /bin/sleep 0.1
done

/usr/bin/log stream \
  --style compact \
  --level info \
  --predicate 'subsystem == "app.said.Said"' \
  >"$log_file" 2>/dev/null &
log_pid=$!
/bin/sleep 0.5
/usr/bin/open -n "$app"

wait_for_log 'Loaded pinned model on Metal' 30 || {
  print -u2 "Said did not load the pinned model on Metal within 30 seconds."
  exit 1
}

/usr/bin/say -r 150 'Said turns audio playing through this Mac into private live captions.'
wait_for_log 'Caption revision' 20 || {
  print -u2 "No caption arrived. Allow Said under System Audio Recording Only, then rerun."
  exit 1
}

pid=$(/usr/bin/pgrep -f "$app/Contents/MacOS/Said" | /usr/bin/head -n 1)
[[ -n "$pid" ]] || { print -u2 "Said exited before the soak began."; exit 1; }

# Warm model/runtime allocations before measuring the RSS trend.
for _ in {1..3}; do
  /usr/bin/say -r 165 'This is a controlled local caption stability check.'
done

started_epoch=$(/bin/date +%s)
next_progress=60
print "Starting ${duration_seconds}-second Said soak; PID $pid"

while true; do
  now_epoch=$(/bin/date +%s)
  elapsed=$(( now_epoch - started_epoch ))
  (( elapsed >= duration_seconds )) && break

  /bin/kill -0 "$pid" 2>/dev/null || {
    print -u2 "Said exited after ${elapsed} seconds."
    exit 1
  }
  if /usr/bin/grep -Eq "$failure_pattern" "$log_file"; then
    print -u2 "Said emitted a bounded-pipeline failure after ${elapsed} seconds."
    exit 1
  fi

  /usr/bin/say -r 175 'Said is checking stable local captions without saving the words.'
  rss_kb=$(/bin/ps -o rss= -p "$pid" | /usr/bin/awk '{print $1}')
  [[ -n "$rss_kb" ]] || { print -u2 "Could not sample Said memory."; exit 1; }
  print "$elapsed $rss_kb" >>"$rss_file"

  if (( elapsed >= next_progress )); then
    print "${elapsed}s: Said alive, RSS $(( rss_kb / 1024 )) MiB"
    (( next_progress += 60 ))
  fi
  /bin/sleep "$sample_interval_seconds"
done

first_rss_kb=$(/usr/bin/awk 'NR == 1 {print $2}' "$rss_file")
last_rss_kb=$(/usr/bin/awk 'END {print $2}' "$rss_file")
maximum_rss_kb=$(/usr/bin/awk 'BEGIN {max=0} {if ($2>max) max=$2} END {print max}' "$rss_file")
sample_count=$(/usr/bin/awk 'END {print NR}' "$rss_file")
caption_revision_count=$(/usr/bin/grep -c 'Caption revision' "$log_file" || true)
rss_growth_kb=$(( last_rss_kb - first_rss_kb ))
failure_count=$(/usr/bin/grep -Ec "$failure_pattern" "$log_file" || true)

(( caption_revision_count > 0 )) || { print -u2 "No caption revisions were observed."; exit 1; }
(( failure_count == 0 )) || { print -u2 "A pipeline failure was observed."; exit 1; }
(( rss_growth_kb <= maximum_rss_growth_kb )) || {
  print -u2 "RSS grew by more than 256 MiB after warmup; investigate before release."
  exit 1
}

/bin/mkdir -p "$receipt_dir"
commit=$(git -C "$repo_root" rev-parse HEAD)
macos_version=$(/usr/bin/sw_vers -productVersion)
hardware=$(/usr/sbin/sysctl -n machdep.cpu.brand_string)
memory_bytes=$(/usr/sbin/sysctl -n hw.memsize)

/usr/bin/printf '%s\n' \
  '{' \
  '  "status": "passed",' \
  "  \"run_id\": \"$run_id\"," \
  "  \"git_commit\": \"$commit\"," \
  "  \"macos_version\": \"$macos_version\"," \
  "  \"hardware\": \"$hardware\"," \
  "  \"memory_bytes\": $memory_bytes," \
  "  \"duration_seconds\": $duration_seconds," \
  "  \"rss_sample_count\": $sample_count," \
  "  \"first_rss_kb\": $first_rss_kb," \
  "  \"last_rss_kb\": $last_rss_kb," \
  "  \"maximum_rss_kb\": $maximum_rss_kb," \
  "  \"rss_growth_kb\": $rss_growth_kb," \
  "  \"caption_revision_count\": $caption_revision_count," \
  "  \"pipeline_failure_count\": $failure_count," \
  '  "content_retained": false' \
  '}' >"$receipt"

print "soak smoke passed"
print -- "- duration: ${duration_seconds} seconds"
print -- "- peak RSS: $(( maximum_rss_kb / 1024 )) MiB"
print -- "- post-warmup RSS change: $(( rss_growth_kb / 1024 )) MiB"
print -- "- receipt: $receipt"
