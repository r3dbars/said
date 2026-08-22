#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
app="$repo_root/dist/Said.app"
installed_model="$HOME/Library/Application Support/Said/Models/parakeet-unified-en-0.6b/parakeet-unified-en-0.6b-Q8_0.gguf"
development_model="$repo_root/Artifacts/Models/parakeet-unified-en-0.6b-Q8_0.gguf"
receipt_dir="$repo_root/Artifacts/Receipts/PostQuitPrivacy"

[[ -d "$app" ]] || { print -u2 "Build Said first with ./scripts/build-and-run.sh --verify"; exit 1; }
[[ -f "$installed_model" || -f "$development_model" ]] || {
  print -u2 "Install the pinned local model before running the post-quit privacy smoke."
  exit 1
}

# These deliberately unusual fixture words are spoken by macOS and searched
# only in Said-owned persistence and Said's unified-log interval. They are not
# user content, and neither they nor recognized caption text enter the receipt.
marker_phrase='marmalade telescope quartz'
marker_words=(${=marker_phrase})
run_id=$(/bin/date -u '+%Y%m%dT%H%M%SZ')
receipt="$receipt_dir/post-quit-privacy-$run_id.json"
live_log=$(/usr/bin/mktemp /private/tmp/said-post-quit-live-log.XXXXXX)
stored_log=$(/usr/bin/mktemp /private/tmp/said-post-quit-stored-log.XXXXXX)
defaults_export=$(/usr/bin/mktemp /private/tmp/said-post-quit-defaults.XXXXXX)
file_list=$(/usr/bin/mktemp /private/tmp/said-post-quit-files.XXXXXX)
log_pid=""

cleanup() {
  if [[ -n "$log_pid" ]]; then
    /bin/kill "$log_pid" 2>/dev/null || true
    wait "$log_pid" 2>/dev/null || true
  fi
  /bin/rm -f "$live_log" "$stored_log" "$defaults_export" "$file_list"
}
trap cleanup EXIT

wait_for_log() {
  local pattern=$1
  local timeout_seconds=$2
  local waited=0
  while (( waited < timeout_seconds )); do
    /usr/bin/grep -q "$pattern" "$live_log" && return 0
    /bin/sleep 1
    (( waited += 1 ))
  done
  return 1
}

caption_revision_count() {
  /usr/bin/grep -c 'Caption revision' "$live_log" 2>/dev/null || true
}

wait_for_new_caption() {
  local previous_count=$1
  local timeout_seconds=$2
  local waited=0
  while (( waited < timeout_seconds )); do
    (( $(caption_revision_count) > previous_count )) && return 0
    /bin/sleep 1
    (( waited += 1 ))
  done
  return 1
}

marker_present_in_file() {
  local candidate=$1
  local marker
  [[ -f "$candidate" ]] || return 1
  for marker in "${marker_words[@]}"; do
    if /usr/bin/grep -aFqi -- "$marker" "$candidate" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

/usr/bin/osascript -e 'tell application "Said" to quit' 2>/dev/null || true
for _ in {1..100}; do
  if ! /usr/bin/pgrep -f "$app/Contents/MacOS/Said" >/dev/null; then
    break
  fi
  /bin/sleep 0.1
done
if /usr/bin/pgrep -f "$app/Contents/MacOS/Said" >/dev/null; then
  print -u2 "The previous Said process did not quit."
  exit 1
fi

log_started_at=$(/bin/date '+%Y-%m-%d %H:%M:%S')
/usr/bin/log stream \
  --style compact \
  --level info \
  --predicate 'subsystem == "app.said.Said"' \
  >"$live_log" 2>/dev/null &
log_pid=$!
/bin/sleep 0.5
/usr/bin/open -n "$app"

wait_for_log 'Loaded pinned model on Metal' 30 || {
  print -u2 "Said did not load the installed model on Metal within 30 seconds."
  exit 1
}

previous_revision_count=$(caption_revision_count)
/usr/bin/say -r 145 "$marker_phrase"
wait_for_new_caption "$previous_revision_count" 20 || {
  print -u2 "The controlled fixture produced no fresh caption revision."
  exit 1
}

/usr/bin/osascript -e 'tell application "Said" to quit' 2>/dev/null || true
for _ in {1..100}; do
  if ! /usr/bin/pgrep -f "$app/Contents/MacOS/Said" >/dev/null; then
    break
  fi
  /bin/sleep 0.1
done
if /usr/bin/pgrep -f "$app/Contents/MacOS/Said" >/dev/null; then
  print -u2 "Said did not terminate after the caption fixture."
  exit 1
fi

/bin/sleep 2
/bin/kill "$log_pid" 2>/dev/null || true
wait "$log_pid" 2>/dev/null || true
log_pid=""

/usr/bin/log show \
  --style compact \
  --info \
  --debug \
  --start "$log_started_at" \
  --predicate 'subsystem == "app.said.Said"' \
  >"$stored_log" 2>/dev/null

/usr/bin/defaults export app.said.Said - >"$defaults_export" 2>/dev/null || true

app_support="$HOME/Library/Application Support/Said"
app_owned_roots=(
  "$HOME/Library/Caches/app.said.Said"
  "$HOME/Library/HTTPStorages/app.said.Said"
  "$HOME/Library/Logs/Said"
  "$HOME/Library/Saved Application State/app.said.Said.savedState"
  "$HOME/Library/WebKit/app.said.Said"
)

if [[ -d "$app_support" ]]; then
  find "$app_support" \
    -path "$app_support/Models" -prune -o \
    -path "$app_support/Downloads" -prune -o \
    -type f -print >>"$file_list"
fi
for root in "${app_owned_roots[@]}"; do
  if [[ -d "$root" ]]; then
    find "$root" -type f -print >>"$file_list"
  elif [[ -f "$root" ]]; then
    print -r -- "$root" >>"$file_list"
  fi
done

marker_match_count=0
for observed_file in "$live_log" "$stored_log" "$defaults_export" "${(@f)$(<"$file_list")}"; do
  [[ -n "$observed_file" ]] || continue
  if marker_present_in_file "$observed_file"; then
    (( marker_match_count += 1 ))
  fi
done

content_like_file_count=0
if [[ -d "$app_support" ]]; then
  content_like_file_count=$(find "$app_support" \
    -path "$app_support/Models" -prune -o \
    -path "$app_support/Downloads" -prune -o \
    -type f \( \
      -iname '*.wav' -o -iname '*.aiff' -o -iname '*.m4a' -o -iname '*.mp3' -o \
      -iname '*.mp4' -o -iname '*.mov' -o -iname '*.txt' -o -iname '*.md' \
    \) -print | /usr/bin/awk 'END {print NR + 0}')
fi

(( marker_match_count == 0 )) || {
  print -u2 "A controlled fixture word remained in Said logs or app-owned storage after quit."
  exit 1
}
(( content_like_file_count == 0 )) || {
  print -u2 "Said left an audio- or transcript-like file after quit."
  exit 1
}

file_count=$(/usr/bin/awk 'END {print NR + 0}' "$file_list")
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
  "  \"app_owned_file_count\": $file_count," \
  "  \"marker_word_count\": ${#marker_words[@]}," \
  "  \"marker_match_count\": $marker_match_count," \
  "  \"content_like_file_count\": $content_like_file_count," \
  '  "local_model_loaded_on_metal": true,' \
  '  "fresh_caption_revision_observed": true,' \
  '  "process_terminated": true,' \
  '  "live_log_scanned": true,' \
  '  "persisted_unified_log_scanned": true,' \
  '  "preferences_scanned": true,' \
  '  "test_marker_scanned": true,' \
  '  "caption_content_inspected": false,' \
  '  "raw_observations_retained": false,' \
  '  "content_retained": false' \
  '}' >"$receipt"

print "post-quit privacy smoke passed"
print -- "- local model produced a fresh caption revision"
print -- "- Said terminated before persistence inspection"
print -- "- controlled fixture matches after quit: $marker_match_count"
print -- "- audio/transcript-like files after quit: $content_like_file_count"
print -- "- raw logs discarded; caption text was not inspected or retained"
print -- "- receipt: $receipt"
