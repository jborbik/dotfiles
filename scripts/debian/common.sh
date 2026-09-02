#!/usr/bin/env bash

function get_highest_tag_version() {
  git tag | grep -E '^v?[0-9]+(\.[0-9]+){1,2}$' | sort -V | tail -n 1
}

function install_rust() {
  if ! [ -x "$(command -v cargo)" ]; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    grep -qxF 'source "$HOME/.cargo/env"' "$HOME/.zshrc" || echo 'source "$HOME/.cargo/env"' >>"$HOME/.zshrc"
    echo "Please source ~/.zshrc or ~/.bashrc"
  fi
}

if [ -f /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  if [ "${ID:-}" = "ubuntu" ]; then
    distro_name="Ubuntu"
  elif [ "${ID:-}" = "debian" ]; then
    distro_name="Debian"
  else
    distro_name="${NAME:-$ID}"
  fi
elif command -v lsb_release >/dev/null 2>&1; then
  distro_name=$(lsb_release -is)
else
  distro_name="Unknown"
fi
export distro_name
