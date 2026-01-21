# ExoDev.app - EXO Development Launcher

This is a lightweight macOS app bundle that allows you to run EXO from source with proper network permissions.

## Why This Exists

When running `uv run exo` directly from the command line, macOS silently blocks mDNS (multicast DNS) discovery because Python doesn't have the proper Info.plist declarations. This prevents EXO from discovering other nodes on your local network.

This launcher app wraps the execution of `uv run exo` and includes the necessary permissions declarations, allowing macOS to:
1. Show a permission dialog for Local Network access (one-time)
2. Grant the app access to use mDNS/Bonjour for peer discovery
3. Allow EXO to function properly without requiring `sudo`

## How to Use

### First Time Setup (Per Machine)

1. **Double-click ExoDev.app** or run from command line:
   ```bash
   open ExoDev.app
   ```

2. **Grant Local Network Permission** when macOS prompts you (this only happens once per machine)

3. The app will launch EXO from the source directory

### Running with Arguments

You can pass any EXO command-line arguments:

```bash
# Verbose logging
open ExoDev.app --args -v

# Very verbose
open ExoDev.app --args -vv

# Force master mode
open ExoDev.app --args --force-master

# Custom API port
open ExoDev.app --args --api-port 8080

# Multiple arguments
open ExoDev.app --args -v --force-master --api-port 8080
```

### Alternative: Command Line Launcher

You can also create a shell alias for convenience:

```bash
# Add to your ~/.zshrc or ~/.bashrc
alias exo-dev='open /Volumes/Developer/Tools/exo/ExoDev.app --args'
```

Then use it like:
```bash
exo-dev -v
exo-dev --force-master
```

## Deploying to Multiple Macs

To use this on other Macs:

1. **Copy the entire exo source directory** (including ExoDev.app) to each Mac
2. **Make sure uv is installed** on each Mac:
   ```bash
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```
3. **Double-click ExoDev.app** on each Mac to trigger the permission dialog
4. Grant Local Network permission when prompted

The app will automatically find the correct source directory relative to its location.

## How It Works

- **Info.plist**: Declares `NSLocalNetworkUsageDescription` and `NSBonjourServices` to request network permissions
- **Launcher Script**: Automatically finds the exo source directory and runs `uv run exo` with your arguments
- **LSUIElement**: Set to `true` so the app doesn't show up in the Dock (runs as a background utility)

## Always Runs Latest Source

This launcher always executes from your current source code. When you pull updates from git, the launcher will automatically use the new code - no need to rebuild anything.

## Troubleshooting

### Permission dialog doesn't appear
- Try running with verbose logging: `open ExoDev.app --args -v`
- Check System Settings → Privacy & Security → Local Network
- Look for "ExoDev" or "EXO (Development)" in the list

### "uv not found" error
Install uv:
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### Can't find source directory
Make sure ExoDev.app is located in the same directory as the exo source code (not moved somewhere else).
