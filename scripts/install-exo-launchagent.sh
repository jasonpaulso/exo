#!/usr/bin/env bash
# Install the io.exo.dev LaunchAgent so `uv run exo` runs in the background
# and starts at login. Idempotent: safe to re-run to refresh the agent.
#
# Custom environment variables can be set two ways:
#   1. Persistent: edit ~/.config/exo/launchd.env (KEY=VALUE per line)
#   2. One-shot: prefix this script, e.g.
#        EXO_MODELS_DIRS=/Volumes/ExternalSSD/exo-models bash $0
# Caller env wins over file; both are merged into the plist.
set -euo pipefail

LABEL="io.exo.dev"
PLIST_PATH="$HOME/Library/LaunchAgents/${LABEL}.plist"
LOG_DIR="$HOME/Library/Logs"
WORKDIR="/Users/jasonschulz/Repos/exo"
UV_BIN="/opt/homebrew/bin/uv"
ENV_FILE="$HOME/.config/exo/launchd.env"
DOMAIN="gui/$(id -u)"
SERVICE="${DOMAIN}/${LABEL}"

if [[ ! -x "$UV_BIN" ]]; then
    echo "ERROR: uv not found at $UV_BIN. Adjust UV_BIN in this script." >&2
    exit 1
fi
if [[ ! -d "$WORKDIR" ]]; then
    echo "ERROR: working dir $WORKDIR does not exist." >&2
    exit 1
fi

mkdir -p "$LOG_DIR" "$(dirname "$PLIST_PATH")"

# --- Build the EnvironmentVariables block --------------------------------
# Layer 1: ~/.config/exo/launchd.env (KEY=VALUE per line, # for comments)
# Layer 2: caller's env, scanning for EXO_*, ENABLE_*, XDG_* (overrides file)
#
# Parallel indexed arrays (not `declare -A`) for bash 3.2 compatibility,
# since macOS ships bash 3.2 forever (GPLv3 avoidance).
EXTRA_KEYS=()
EXTRA_VALS=()

set_env_kv() {
    local k="$1" v="$2" i
    for i in "${!EXTRA_KEYS[@]}"; do
        if [[ "${EXTRA_KEYS[$i]}" == "$k" ]]; then
            EXTRA_VALS[$i]="$v"
            return
        fi
    done
    EXTRA_KEYS+=("$k")
    EXTRA_VALS+=("$v")
}

if [[ -f "$ENV_FILE" ]]; then
    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        # Strip CR if present, skip blanks/comments
        line="${raw_line%$'\r'}"
        [[ -z "${line//[[:space:]]/}" ]] && continue
        [[ "${line#"${line%%[![:space:]]*}"}" == \#* ]] && continue
        # Split on first =
        if [[ "$line" != *"="* ]]; then continue; fi
        key="${line%%=*}"
        val="${line#*=}"
        # Trim surrounding whitespace from key
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"
        # Strip surrounding single or double quotes from val
        if [[ "$val" == \"*\" ]]; then val="${val%\"}"; val="${val#\"}"
        elif [[ "$val" == \'*\' ]]; then val="${val%\'}"; val="${val#\'}"; fi
        set_env_kv "$key" "$val"
    done < "$ENV_FILE"
fi

# Forward any caller-set EXO_*, ENABLE_*, XDG_* vars (override file values)
for varname in ${!EXO_@} ${!ENABLE_@} ${!XDG_@}; do
    set_env_kv "$varname" "${!varname}"
done

# XML-escape helper (covers &, <, > — sufficient for paths and simple values)
xml_escape() {
    local s="$1"
    s="${s//&/&amp;}"
    s="${s//</&lt;}"
    s="${s//>/&gt;}"
    printf '%s' "$s"
}

# Render the <EnvironmentVariables> dict body
render_env_block() {
    printf '        <key>PATH</key>\n'
    printf '        <string>/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>\n'
    printf '        <key>HOME</key>\n        <string>%s</string>\n' "$(xml_escape "$HOME")"
    printf '        <key>LANG</key>\n        <string>en_US.UTF-8</string>\n'
    local i
    for i in "${!EXTRA_KEYS[@]}"; do
        printf '        <key>%s</key>\n        <string>%s</string>\n' \
            "$(xml_escape "${EXTRA_KEYS[$i]}")" "$(xml_escape "${EXTRA_VALS[$i]}")"
    done
}
ENV_BLOCK="$(render_env_block)"

echo "Environment variables that will be baked into the plist:"
echo "  PATH=<homebrew + system>"
echo "  HOME=$HOME"
echo "  LANG=en_US.UTF-8"
if (( ${#EXTRA_KEYS[@]} > 0 )); then
    for i in "${!EXTRA_KEYS[@]}"; do
        echo "  ${EXTRA_KEYS[$i]}=${EXTRA_VALS[$i]}"
    done
else
    echo "  (no extras - set them in $ENV_FILE or pass on command line)"
fi
echo

# Unload first if already present, so the new plist is picked up.
if launchctl print "$SERVICE" >/dev/null 2>&1; then
    echo "Unloading existing ${SERVICE}…"
    launchctl bootout "$SERVICE" || true
fi

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${UV_BIN}</string>
        <string>run</string>
        <string>exo</string>
    </array>
    <key>WorkingDirectory</key>
    <string>${WORKDIR}</string>
    <key>EnvironmentVariables</key>
    <dict>
${ENV_BLOCK}
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>30</integer>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/exo.out.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/exo.err.log</string>
</dict>
</plist>
PLIST

echo "Linting plist…"
plutil -lint "$PLIST_PATH"

echo "Bootstrapping ${SERVICE}…"
launchctl bootstrap "$DOMAIN" "$PLIST_PATH"

echo "Waiting for boot…"
sleep 3

echo
echo "=== Service status ==="
launchctl print "$SERVICE" | grep -E "state|pid|last exit code|program ="

echo
echo "=== Tail of stdout (last 20 lines) ==="
tail -n 20 "$LOG_DIR/exo.out.log" 2>/dev/null || echo "(no stdout yet)"

echo
echo "=== Tail of stderr (last 20 lines) ==="
tail -n 20 "$LOG_DIR/exo.err.log" 2>/dev/null || echo "(no stderr yet)"

echo
echo "Probing API…"
for i in 1 2 3 4 5 6 7 8 9 10; do
    if curl -sf --max-time 2 "http://localhost:52415/v1/models" >/dev/null 2>&1; then
        echo "exo API is responding on http://localhost:52415"
        exit 0
    fi
    sleep 2
done
echo "exo API did not respond within 20s. Check $LOG_DIR/exo.err.log for errors." >&2
exit 1
