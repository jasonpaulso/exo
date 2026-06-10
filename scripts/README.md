# exo helper scripts

Scripts for running exo as a background macOS LaunchAgent and managing
a shared model store across cluster nodes.

## What's here

| File | Purpose |
| --- | --- |
| `install-exo-launchagent.sh` | Install/refresh the `io.exo.dev` LaunchAgent so `uv run exo` runs in the background and starts at login. Idempotent. |
| `exo-service.sh` | Convenience wrapper around `launchctl` for start/stop/restart/status/logs. |
| `sync-models-to-share.sh` | Push/pull exo model weights between this node's local cache and a shared network drive. |

## First-time setup on a new node

```bash
# Install + start the agent (also bootstraps it; idempotent)
bash scripts/install-exo-launchagent.sh

# Verify the service
bash scripts/exo-service.sh status

# Open the dashboard
open http://localhost:52415
```

Logs land at:

- `~/Library/Logs/exo.out.log`
- `~/Library/Logs/exo.err.log`

## Setting environment variables

The launch agent does **not** inherit your shell environment — env vars
must be baked into the plist. The installer reads them from two
sources, with caller-env winning over the file:

**Persistent** (recommended): edit `~/.config/exo/launchd.env` with one
`KEY=VALUE` per line (comments with `#` allowed). Then re-run the
installer to apply.

```bash
mkdir -p ~/.config/exo
cat >> ~/.config/exo/launchd.env <<'EOF'
EXO_OFFLINE=false
EXO_MAX_CONCURRENT_REQUESTS=8
EOF
bash scripts/install-exo-launchagent.sh
```

**One-shot**: prefix the installer.

```bash
EXO_OFFLINE=true bash scripts/install-exo-launchagent.sh
```

The installer prints the env block before bootstrapping so you can
sanity-check what's being written.

### Recognized env vars

See `src/exo/shared/constants.py` for the source of truth. Highlights:

| Var | Purpose | Default |
| --- | --- | --- |
| `EXO_HOME` | Base data dir | `~/.exo` |
| `EXO_DEFAULT_MODELS_DIR` | Primary writable models dir | `$EXO_HOME/models` |
| `EXO_MODELS_DIRS` | Colon-separated extra writable dirs | none |
| `EXO_MODELS_READ_ONLY_DIRS` | Colon-separated read-only model dirs | none |
| `EXO_OFFLINE` | Skip all network downloads | `false` |
| `EXO_ENABLE_IMAGE_MODELS` | Enable diffusion/image models | `false` |
| `EXO_TRACING_ENABLED` | Emit tracing data | `false` |
| `EXO_MAX_CONCURRENT_REQUESTS` | Max parallel requests | `8` |
| `ENABLE_DISAGGREGATION` | Enable prefill/decode split | `false` |

To verify what the running agent actually sees:

```bash
launchctl print gui/$(id -u)/io.exo.dev | grep -A 30 'environment ='
```

## Service management

```bash
bash scripts/exo-service.sh start        # bootstrap the agent
bash scripts/exo-service.sh stop         # bootout (without removing plist)
bash scripts/exo-service.sh restart      # stop + start
bash scripts/exo-service.sh status       # state, pid, last exit code
bash scripts/exo-service.sh logs         # tail -f stdout + stderr
bash scripts/exo-service.sh tail-out     # follow stdout
bash scripts/exo-service.sh tail-err     # follow stderr
```

## Shared model store across the cluster

When you run a multi-node exo cluster, each node would otherwise
download its own copy of every model. Two strategies for sharing:

### Strategy A (recommended): pull-to-local + RDMA-friendly

Use the network share as a **sync staging area**, not a runtime mount.
Each node keeps weights on its local SSD; the share is only touched
when you want to propagate a newly-downloaded model.

**Why**: exo's RDMA tensor transport runs over Thunderbolt's
`rdma_interface`. Apple's TB Bridge IP networking and the RDMA mode
share the same physical TB port and **cannot both be active**. If you
mount the share at runtime via `EXO_MODELS_READ_ONLY_DIRS`, every cold
model load happens over your slowest network path while TB sits idle
in RDMA mode. Pulling weights to local first decouples the two: sync
when convenient, run inference at full local NVMe speed with TB free
for RDMA.

Workflow:

```bash
# On the node that downloaded a new model:
bash scripts/sync-models-to-share.sh push

# On every other node, before next inference run:
bash scripts/sync-models-to-share.sh pull
```

No `EXO_MODELS_READ_ONLY_DIRS` is set — exo just uses its local
default dir, which now contains the synced weights.

### Strategy B: read-only-share-at-runtime

Simpler operationally, but accepts cold-load latency over your
network and forfeits TB for RDMA (since you'll want TB Bridge for
faster share access).

```bash
mkdir -p ~/.config/exo
echo 'EXO_MODELS_READ_ONLY_DIRS=/Volumes/Models/Models' \
    >> ~/.config/exo/launchd.env
bash scripts/install-exo-launchagent.sh
```

Code path: `download_utils.py:resolve_existing_model` searches
read-only dirs first, finds a complete model in the share, and skips
the download. The share is filtered out of writable-dir lists so exo
will never write to or delete from it. `is_read_only_model_dir()` also
prevents the dashboard's "Uninstall model" action from touching it.

## sync-models-to-share.sh reference

```
sync-models-to-share.sh push                       # local -> share (default)
sync-models-to-share.sh pull                       # share -> local
sync-models-to-share.sh push --dry-run             # preview push
sync-models-to-share.sh pull --model <org/name>    # sync only one model
sync-models-to-share.sh push --delete              # mirror mode (destructive, prompts)
```

Env overrides:

- `EXO_LOCAL_MODELS_DIR` — default `$HOME/.exo/models`
- `EXO_SHARE_DIR` — default `/Volumes/Models/Models`

The share's directory layout mirrors exo's normalized model-id tree:

```
/Volumes/Models/Models/
  mlx-community/
    Qwen3-30B-A3B-4bit/
      config.json
      model.safetensors.index.json
      model-00001-of-00004.safetensors
      ...
```

The script preserves this structure automatically.

## Uninstall

```bash
bash scripts/exo-service.sh stop                # stop without disabling
launchctl bootout gui/$(id -u)/io.exo.dev       # also disables auto-start
rm ~/Library/LaunchAgents/io.exo.dev.plist      # full uninstall
```

This does not touch `~/.exo/` or any downloaded models.
