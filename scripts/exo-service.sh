#!/usr/bin/env bash
# Service wrapper for the io.exo.dev LaunchAgent.
# Usage: exo-service {start|stop|restart|status|logs|tail-out|tail-err}
set -euo pipefail

LABEL="io.exo.dev"
PLIST_PATH="$HOME/Library/LaunchAgents/${LABEL}.plist"
LOG_DIR="$HOME/Library/Logs"
DOMAIN="gui/$(id -u)"
SERVICE="${DOMAIN}/${LABEL}"

cmd="${1:-status}"

case "$cmd" in
    start)
        if [[ ! -f "$PLIST_PATH" ]]; then
            echo "Plist missing at $PLIST_PATH. Run install-exo-launchagent.sh first." >&2
            exit 1
        fi
        launchctl bootstrap "$DOMAIN" "$PLIST_PATH"
        echo "Started ${LABEL}"
        ;;
    stop)
        launchctl bootout "$SERVICE" 2>/dev/null || echo "(was not loaded)"
        echo "Stopped ${LABEL}"
        ;;
    restart)
        "$0" stop || true
        sleep 1
        "$0" start
        ;;
    status)
        if launchctl print "$SERVICE" >/dev/null 2>&1; then
            launchctl print "$SERVICE" | grep -E "state|pid|last exit code|program ="
        else
            echo "Not loaded"
        fi
        ;;
    logs)
        tail -f "$LOG_DIR/exo.out.log" "$LOG_DIR/exo.err.log"
        ;;
    tail-out)
        tail -f "$LOG_DIR/exo.out.log"
        ;;
    tail-err)
        tail -f "$LOG_DIR/exo.err.log"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|tail-out|tail-err}" >&2
        exit 1
        ;;
esac
