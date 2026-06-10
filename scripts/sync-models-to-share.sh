#!/usr/bin/env bash
# Sync exo model weights between this node and a shared network store.
#
# Default mode is "push": copy locally-downloaded models from
# ~/.exo/models up to the share so other nodes can grab them.
#
# "pull" mode goes the other way: hydrate this node's local cache from
# the share. Use this on a fresh node, or after another node has
# downloaded a new model and pushed it.
#
# This is the recommended pattern when you want RDMA tensor transport
# over Thunderbolt: the share is a sync staging area, never a runtime
# mount. Models live on each node's local SSD; TB stays free for RDMA.
#
# Usage:
#   bash scripts/sync-models-to-share.sh push                       # local -> share (default)
#   bash scripts/sync-models-to-share.sh pull                       # share -> local
#   bash scripts/sync-models-to-share.sh push --dry-run             # preview push
#   bash scripts/sync-models-to-share.sh pull --model mlx-community/Qwen3-30B-A3B-4bit
#   bash scripts/sync-models-to-share.sh push --delete              # mirror (destructive, prompts)
#
# Env overrides:
#   EXO_LOCAL_MODELS_DIR  default: $HOME/.exo/models
#   EXO_SHARE_DIR         default: /Volumes/Models/Models

set -euo pipefail

LOCAL_DIR="${EXO_LOCAL_MODELS_DIR:-$HOME/.exo/models}"
SHARE_DIR="${EXO_SHARE_DIR:-/Volumes/Models/Models}"

DIRECTION="${1:-push}"
case "$DIRECTION" in
    push|pull) shift ;;
    -h|--help|help)
        sed -n '2,25p' "$0" | sed 's/^# //; s/^#//'
        exit 0
        ;;
    *)
        echo "ERROR: first arg must be 'push' or 'pull' (got: $DIRECTION)" >&2
        exit 2
        ;;
esac

DRY_RUN=0
DELETE=0
MODEL=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run|-n) DRY_RUN=1; shift ;;
        --delete) DELETE=1; shift ;;
        --model) MODEL="${2:-}"; shift 2 ;;
        -h|--help) sed -n '2,25p' "$0" | sed 's/^# //; s/^#//'; exit 0 ;;
        *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

if [[ ! -d "$LOCAL_DIR" ]]; then
    if [[ "$DIRECTION" == "pull" ]]; then
        echo "Local dir $LOCAL_DIR does not exist; creating."
        mkdir -p "$LOCAL_DIR"
    else
        echo "ERROR: local dir $LOCAL_DIR not found; nothing to push." >&2
        exit 1
    fi
fi
if [[ ! -d "$SHARE_DIR" ]]; then
    echo "ERROR: share $SHARE_DIR is not mounted." >&2
    echo "Mount it first (Finder: Cmd+K -> smb://<host>/Models)" >&2
    exit 1
fi

# Sanity: refuse to sync if local and share resolve to the same volume.
if [[ "$(stat -f %d "$LOCAL_DIR")" == "$(stat -f %d "$SHARE_DIR")" ]]; then
    echo "ERROR: $LOCAL_DIR and $SHARE_DIR appear to be on the same volume." >&2
    echo "       The share is likely not actually mounted." >&2
    exit 1
fi

if [[ "$DIRECTION" == "push" ]]; then
    SRC_BASE="$LOCAL_DIR"
    DST_BASE="$SHARE_DIR"
    ARROW="local -> share"
else
    SRC_BASE="$SHARE_DIR"
    DST_BASE="$LOCAL_DIR"
    ARROW="share -> local"
fi

if [[ -n "$MODEL" ]]; then
    SRC="$SRC_BASE/$MODEL/"
    DST="$DST_BASE/$MODEL/"
    if [[ ! -d "$SRC" ]]; then
        echo "ERROR: model dir not found at $SRC" >&2
        exit 1
    fi
    mkdir -p "$DST"
else
    SRC="$SRC_BASE/"
    DST="$DST_BASE/"
fi

RSYNC_OPTS=(
    -ah                            # archive, human-readable
    --partial                      # keep partial files for resume
    --info=progress2,stats2        # overall progress, summary stats
    --exclude='.DS_Store'
    --exclude='._*'                # macOS resource forks
    --exclude='*.tmp'
    --exclude='*.lock'
    --exclude='.Trashes'
    --exclude='.Spotlight-V100'
    --exclude='.fseventsd'
)
(( DRY_RUN )) && RSYNC_OPTS+=(--dry-run)
(( DELETE ))  && RSYNC_OPTS+=(--delete)

echo "exo model sync"
echo "  direction : $DIRECTION  ($ARROW)"
echo "  src       : $SRC"
echo "  dst       : $DST"
(( DRY_RUN )) && echo "  mode      : DRY RUN (no changes)"
(( DELETE ))  && echo "  mode      : MIRROR (will delete extras in dst)"
echo

if (( DELETE )) && (( ! DRY_RUN )); then
    read -r -p "Mirror mode is destructive. Proceed? [y/N] " reply
    case "$reply" in [Yy]*) ;; *) echo "Aborted."; exit 0 ;; esac
fi

rsync "${RSYNC_OPTS[@]}" "$SRC" "$DST"

echo
echo "Done."
if [[ "$DIRECTION" == "push" ]]; then
    echo "Other nodes can now pull these models with:"
    echo "  bash scripts/sync-models-to-share.sh pull"
else
    echo "Models are now in $DST_BASE and will be picked up by exo on next launch."
fi
