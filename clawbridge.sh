#!/bin/bash
set -euo pipefail

BRIDGE_DIR="$(dirname "$(realpath "$0")")"
CONFIG="$BRIDGE_DIR/clawbridge.yaml"
TRIGGERDIR="$BRIDGE_DIR/TRIGGERDIR"
LOG_FILE="$BRIDGE_DIR/logs/CLAWBRIDGE.log"
DROP_LOG="$BRIDGE_DIR/logs/DROP.log"

log()  { mkdir -p "$BRIDGE_DIR/logs"; printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"; }
inbox(){ mkdir -p "$BRIDGE_DIR/logs"; printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$DROP_LOG"; }

safe_rm() {
    if ! rm -f "$1" 2>/dev/null; then
        log "FATAL cannot delete $(basename "$1") – wrong permissions? shutting down"
        exit 1
    fi
}

declare -A JOB_SCRIPTS JOB_MODES
while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*[#$] ]] && continue
    [[ "$line" =~ ^[[:space:]]{2}([a-zA-Z0-9_]+):[[:space:]]*$ ]] && { current_job="${BASH_REMATCH[1]}"; continue; }
    if [[ "$line" =~ ^[[:space:]]{4}script:[[:space:]]*(.+)$ ]]; then
        path="$(eval echo "${BASH_REMATCH[1]}")"
        [[ "$path" == ./* ]] && path="$BRIDGE_DIR/${path#./}"
        JOB_SCRIPTS[$current_job]="$path"
    fi
    [[ "$line" =~ ^[[:space:]]{4}mode:[[:space:]]*(.+)$ ]] && JOB_MODES[$current_job]="${BASH_REMATCH[1]}"
done < "$CONFIG"

run_job() {
    local job="$1" script="${JOB_SCRIPTS[$1]}"
    [ ! -x "$script" ] && { log "ERROR [$job] nicht ausführbar: $script"; return; }
    safe_rm "$TRIGGERDIR/${job}"
    log "START [$job]"
    ( if "$script" >> "$LOG_FILE" 2>&1; then log "OK    [$job]"
      else log "ERROR [$job] exit=$?"; fi ) &
}

process() {
    local f="$1" name; name=$(basename "$f")
    if [ -n "${JOB_SCRIPTS[$name]+_}" ]; then
        [ "${JOB_MODES[$name]:-}" = "cron" ] && return
        run_job "$name"
    else
        inbox "DROPPED $name $(stat -c '%s' "$f" 2>/dev/null)B"
        safe_rm "$f"
    fi
}

for f in "$TRIGGERDIR"/*; do [ -f "$f" ] && process "$f"; done

inotifywait -m -e close_write,moved_to --format '%w%f' "$TRIGGERDIR" 2>/dev/null | \
while IFS= read -r f; do process "$f"; sleep 60; done
