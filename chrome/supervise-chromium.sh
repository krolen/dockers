#!/usr/bin/env bash
set -uo pipefail

readonly STATUS_FILE=/config/.chromium-supervisor-status.json
readonly MAX_RESTART_ATTEMPTS=3
readonly STABLE_RUN_SECONDS=300

restart_attempts=0

write_status() {
    local state=$1 last_exit_code=$2 last_run_seconds=$3
    local temporary_file="${STATUS_FILE}.tmp.$$"

    printf '{"state":"%s","restart_attempts":%d,"max_restart_attempts":%d,"stable_run_seconds":%d,"last_exit_code":%s,"last_run_seconds":%s,"updated_at":"%s"}\n' \
        "$state" \
        "$restart_attempts" \
        "$MAX_RESTART_ATTEMPTS" \
        "$STABLE_RUN_SECONDS" \
        "$last_exit_code" \
        "$last_run_seconds" \
        "$(date --iso-8601=seconds)" > "$temporary_file"
    mv -f -- "$temporary_file" "$STATUS_FILE"
}

write_status starting null null

while true; do
    started_at=$(date +%s)
    write_status running null null

    # CHROME_CLI intentionally undergoes shell word splitting, matching the
    # image's original Labwc autostart command.
    # shellcheck disable=SC2086
    wrapped-chromium ${CHROME_CLI:-}
    exit_code=$?
    run_seconds=$(( $(date +%s) - started_at ))

    # A browser that ran normally for a while gets a fresh recovery budget.
    if (( run_seconds >= STABLE_RUN_SECONDS )); then
        restart_attempts=0
    fi

    if (( restart_attempts >= MAX_RESTART_ATTEMPTS )); then
        write_status failed "$exit_code" "$run_seconds"
        # Latch until the Chrome container is deliberately restarted.
        exec sleep infinity
    fi

    restart_attempts=$((restart_attempts + 1))
    write_status restarting "$exit_code" "$run_seconds"
    sleep $((restart_attempts * 5))
done
