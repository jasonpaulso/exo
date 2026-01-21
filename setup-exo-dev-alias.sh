#!/bin/bash

# Setup script to add exo-dev alias to your shell configuration

EXO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH="$EXO_DIR/ExoDev.app"

# Detect shell
SHELL_NAME=$(basename "$SHELL")
if [ "$SHELL_NAME" = "zsh" ]; then
    RC_FILE="$HOME/.zshrc"
elif [ "$SHELL_NAME" = "bash" ]; then
    RC_FILE="$HOME/.bashrc"
else
    echo "Unknown shell: $SHELL_NAME"
    echo "Please manually add this alias to your shell configuration:"
    echo "alias exo-dev='open $APP_PATH --args'"
    exit 1
fi

# Check if alias already exists
if grep -q "alias exo-dev=" "$RC_FILE" 2>/dev/null; then
    echo "✓ exo-dev alias already exists in $RC_FILE"
    echo ""
    echo "Current alias:"
    grep "alias exo-dev=" "$RC_FILE"
    echo ""
    read -p "Do you want to update it? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing alias"
        exit 0
    fi
    # Remove old alias
    sed -i '' '/alias exo-dev=/d' "$RC_FILE"
fi

# Add alias
echo "" >> "$RC_FILE"
echo "# EXO Development launcher alias" >> "$RC_FILE"
echo "alias exo-dev='open $APP_PATH --args'" >> "$RC_FILE"

echo "✓ Added exo-dev alias to $RC_FILE"
echo ""
echo "To use it now, run:"
echo "  source $RC_FILE"
echo ""
echo "Then you can run EXO with:"
echo "  exo-dev -v"
echo "  exo-dev --force-master"
echo "  exo-dev --api-port 8080"
