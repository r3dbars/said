#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
app="$repo_root/dist/Said.app"
subsystem=app.said.Said
log_file=$(/usr/bin/mktemp /private/tmp/said-capture-smoke.XXXXXX)
log_pid=""

cleanup() {
  if [[ -n "$log_pid" ]]; then
    /bin/kill "$log_pid" 2>/dev/null || true
    wait "$log_pid" 2>/dev/null || true
  fi
  /bin/rm -f "$log_file"
}
trap cleanup EXIT

[[ -d "$app" ]] || {
  print -u2 "Build Said first with ./scripts/build-and-run.sh --verify"
  exit 1
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
  --predicate "subsystem == '$subsystem'" \
  >"$log_file" 2>/dev/null &
log_pid=$!
/bin/sleep 0.5
/usr/bin/open -n "$app"

read_logs() {
  /bin/cat "$log_file"
}

model_ready=false
for _ in {1..20}; do
  if read_logs | /usr/bin/grep -q 'Loaded pinned model on Metal'; then
    model_ready=true
    break
  fi
  /bin/sleep 1
done

if [[ "$model_ready" != true ]]; then
  print -u2 "Said did not report a ready local model within 20 seconds."
  print -u2 "Open Said from the menu bar, finish setup if needed, then rerun this smoke test."
  exit 1
fi

/usr/bin/say -r 150 'Said turns the audio playing through this Mac into private live captions.'

caption_seen=false
for _ in {1..20}; do
  if read_logs | /usr/bin/grep -q 'Caption revision'; then
    caption_seen=true
    break
  fi
  /bin/sleep 1
done

if [[ "$caption_seen" != true ]]; then
  print -u2 "No caption revision arrived within 20 seconds."
  print -u2 "Allow Said under System Audio Recording Only, play Mac audio, and rerun this command."
  exit 1
fi

print "capture smoke passed"
print -- "- pinned local model loaded on Metal"
print -- "- synthesized Mac playback reached the caption pipeline"
print -- "- validation used content-free operational logs"
