#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
app="$repo_root/dist/Said.app"
installed_model="$HOME/Library/Application Support/Said/Models/parakeet-unified-en-0.6b/parakeet-unified-en-0.6b-Q8_0.gguf"
development_model="$repo_root/Artifacts/Models/parakeet-unified-en-0.6b-Q8_0.gguf"
post_caption_seconds=10

while (( $# > 0 )); do
  case "$1" in
    --post-caption-seconds)
      [[ ${2:-} == <-> ]] || { print -u2 "--post-caption-seconds requires a whole number"; exit 2; }
      post_caption_seconds=$2
      shift 2
      ;;
    *)
      print -u2 "usage: $0 [--post-caption-seconds WHOLE_NUMBER]"
      exit 2
      ;;
  esac
done

(( post_caption_seconds > 0 )) || { print -u2 "post-caption observation must be greater than zero"; exit 2; }
[[ -d "$app" ]] || { print -u2 "Build Said first with ./scripts/build-and-run.sh --verify"; exit 1; }
[[ -f "$installed_model" || -f "$development_model" ]] || {
  print -u2 "Install the pinned local model before running the offline smoke."
  exit 1
}

receipt_dir="$repo_root/Artifacts/Receipts/Offline"
run_id=$(/bin/date -u '+%Y%m%dT%H%M%SZ')
receipt="$receipt_dir/offline-$run_id.json"
log_file=$(/usr/bin/mktemp /private/tmp/said-offline-log.XXXXXX)
nettop_file=$(/usr/bin/mktemp /private/tmp/said-offline-nettop.XXXXXX)
lsof_file=$(/usr/bin/mktemp /private/tmp/said-offline-lsof.XXXXXX)
lsof_samples_file=$(/usr/bin/mktemp /private/tmp/said-offline-lsof-samples.XXXXXX)
stop_marker=$(/usr/bin/mktemp /private/tmp/said-offline-stop.XXXXXX)
/bin/rm -f "$stop_marker"
log_pid=""
nettop_pid=""
lsof_pid=""

cleanup() {
  /usr/bin/touch "$stop_marker" 2>/dev/null || true
  for monitor_pid in "$lsof_pid" "$nettop_pid" "$log_pid"; do
    if [[ -n "$monitor_pid" ]]; then
      /bin/kill "$monitor_pid" 2>/dev/null || true
      wait "$monitor_pid" 2>/dev/null || true
    fi
  done
  /bin/rm -f "$log_file" "$nettop_file" "$lsof_file" "$lsof_samples_file" "$stop_marker"
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
started_epoch=$(/bin/date +%s)
/usr/bin/open -n "$app"

pid=""
for _ in {1..50}; do
  pid=$(/usr/bin/pgrep -f "$app/Contents/MacOS/Said" | /usr/bin/head -n 1 || true)
  [[ -n "$pid" ]] && break
  /bin/sleep 0.1
done
[[ -n "$pid" ]] || { print -u2 "Said did not launch."; exit 1; }

# lsof begins immediately after process identification and polls four times per
# second, including while the installed model is loading.
(
  while [[ ! -e "$stop_marker" ]]; do
    /usr/sbin/lsof -nP -a -p "$pid" -i >>"$lsof_file" 2>/dev/null || true
    print 1 >>"$lsof_samples_file"
    /bin/sleep 0.25
  done
) &
lsof_pid=$!

wait_for_log 'Loaded pinned model on Metal' 30 || {
  print -u2 "Said did not load the installed model on Metal within 30 seconds."
  exit 1
}

# nettop uses a finite sample count so it exits normally and flushes its CSV.
# Its window covers playback, the complete caption timeout, and the requested
# quiet post-caption interval. Both tools therefore overlap live inference.
nettop_sample_target=$(( post_caption_seconds + 25 ))
/usr/bin/nettop -n -x -L "$nettop_sample_target" -s 1 -p "$pid" >"$nettop_file" 2>/dev/null &
nettop_pid=$!

/usr/bin/say -r 150 'Said captions this playback locally without opening a network connection.'
wait_for_log 'Caption revision' 20 || {
  print -u2 "No caption revision arrived during offline observation."
  exit 1
}

/bin/sleep "$post_caption_seconds"
/usr/bin/touch "$stop_marker"
wait "$lsof_pid" 2>/dev/null || true
lsof_pid=""
wait "$nettop_pid" 2>/dev/null || true
nettop_pid=""

nettop_sample_count=$(/usr/bin/grep -c '^time,,' "$nettop_file" || true)
nettop_connection_row_count=$(
  /usr/bin/grep -v '^time,,' "$nettop_file" \
    | /usr/bin/grep -c '[^[:space:]]' || true
)
lsof_sample_count=$(/usr/bin/awk 'END {print NR + 0}' "$lsof_samples_file")
lsof_socket_row_count=$(/usr/bin/grep -c '[^[:space:]]' "$lsof_file" || true)

(( nettop_sample_count > 0 )) || { print -u2 "nettop produced no observation samples."; exit 1; }
(( lsof_sample_count > 0 )) || { print -u2 "lsof produced no observation samples."; exit 1; }
(( nettop_connection_row_count == 0 )) || {
  print -u2 "nettop observed a Said network connection during captioning."
  exit 1
}
(( lsof_socket_row_count == 0 )) || {
  print -u2 "lsof observed a Said Internet socket during captioning."
  exit 1
}

/bin/mkdir -p "$receipt_dir"
commit=$(git -C "$repo_root" rev-parse HEAD)
macos_version=$(/usr/bin/sw_vers -productVersion)
hardware=$(/usr/sbin/sysctl -n machdep.cpu.brand_string)
memory_bytes=$(/usr/sbin/sysctl -n hw.memsize)
duration_seconds=$(( $(/bin/date +%s) - started_epoch ))

/usr/bin/printf '%s\n' \
  '{' \
  '  "status": "passed",' \
  "  \"run_id\": \"$run_id\"," \
  "  \"git_commit\": \"$commit\"," \
  "  \"macos_version\": \"$macos_version\"," \
  "  \"hardware\": \"$hardware\"," \
  "  \"memory_bytes\": $memory_bytes," \
  "  \"duration_seconds\": $duration_seconds," \
  "  \"post_caption_seconds\": $post_caption_seconds," \
  "  \"nettop_sample_count\": $nettop_sample_count," \
  "  \"nettop_connection_row_count\": $nettop_connection_row_count," \
  "  \"lsof_sample_count\": $lsof_sample_count," \
  "  \"lsof_socket_row_count\": $lsof_socket_row_count," \
  '  "local_model_loaded_on_metal": true,' \
  '  "caption_revision_observed": true,' \
  '  "runtime_network_observation_performed": true,' \
  '  "content_inspected": false,' \
  '  "content_retained": false' \
  '}' >"$receipt"

print "offline caption smoke passed"
print -- "- local model loaded on Metal and produced captions"
print -- "- nettop connection rows: $nettop_connection_row_count across $nettop_sample_count samples"
print -- "- lsof socket rows: $lsof_socket_row_count across $lsof_sample_count samples"
print -- "- raw observations discarded; no caption text inspected"
print -- "- receipt: $receipt"
