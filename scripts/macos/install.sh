#!/usr/bin/env zsh
set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(dirname "$(dirname "$SCRIPT_DIR")")

"$SCRIPT_DIR/../set_up_common.sh"

KEYBOARD_SOURCE_PATH="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Random/Keyboard Layouts/Polish-German.bundle"
KEYBOARD_TARGET_PATH="$HOME/Library/Keyboard Layouts/Polish-German.bundle"
if [ -e "$KEYBOARD_SOURCE_PATH" ] && [ ! -e "$KEYBOARD_TARGET_PATH" ]; then
  cp -R "$KEYBOARD_SOURCE_PATH" "$KEYBOARD_TARGET_PATH"
  echo "Reboot and add the Polish-German keyboard layout from Polish keyboards"
fi

SSH_CONFIG_DIR=/etc/ssh/sshd_config.d
SSH_CONFIG_PATH="$SSH_CONFIG_DIR/100-macos.conf"
if [ -d "$SSH_CONFIG_DIR" ] && { [ ! -f "$SSH_CONFIG_PATH" ] || ! grep -Fxq "PasswordAuthentication no" "$SSH_CONFIG_PATH"; }; then
  echo "PasswordAuthentication no" | sudo tee -a "$SSH_CONFIG_PATH" >/dev/null
  echo "ChallengeResponseAuthentication no" | sudo tee -a "$SSH_CONFIG_PATH" >/dev/null
fi

# run goku to install karabiner config
goku > /dev/null || echo "goku not installed. Install with brew and run 'goku' when possible."

"$SCRIPT_DIR/set_defaults.sh"

echo "Install all packages with: brew bundle install --file \"$HOME/Library/Mobile Documents/com~apple~CloudDocs/.Brewfile\""
echo "Dump all packages later with: brew bundle dump --casks --taps --brews --mas --force --file \"$HOME/Library/Mobile Documents/com~apple~CloudDocs/.Brewfile\""
