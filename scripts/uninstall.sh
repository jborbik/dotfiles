#!/usr/bin/env bash
set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

cd "$ROOT_DIR"

# Private submodule uninstall
SUBMODULE_PATH="dotfiles_private"

# Check if the submodule is not empty
if [ -d "${SUBMODULE_PATH}" ] && [ -n "$(ls -A "${SUBMODULE_PATH}" 2>/dev/null)" ]; then
  echo "Private submodule is available. Uninstalling..."
  "${SUBMODULE_PATH}/scripts/uninstall.sh"
else
  echo "Private submodule is not cloned. Skipping uninstallation."
fi

cd stow

# Unstow platform-specific config
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  stow --dotfiles -D -t ~ debian
  vscode_snippets_path="$HOME/.config/Code/User/snippets"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  stow --dotfiles -D -t ~ macos
  vscode_snippets_path="$HOME/Library/Application Support/Code/User/snippets"
  rm -f "$HOME/.stow-global-ignore"
else
  echo "Unsupported OS"
  exit 1
fi

# Unstow common
stow --dotfiles -D -t ~ common

# Remove snippets symlink if created by install.sh
if [ -L "${vscode_snippets_path:-}" ]; then
  rm -f "$vscode_snippets_path"
fi
