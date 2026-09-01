#!/usr/bin/env bash

set -x
set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Initialize flags
dev=false
install_only=false
stow_only=false

function install_stow_debian {
  if ! [ -x "$(command -v perl)" ]; then
    sudo apt install perl -y
  fi
  current_dir=$(pwd)

  cd /tmp
  wget https://mirror.fcix.net/gnu/stow/stow-latest.tar.gz

  tar -xzf stow-latest.tar.gz

  # Find the extracted directory (it should match "stow-X.Y.Z")
  dir_name=$(tar -tzf stow-latest.tar.gz | head -1 | cut -f1 -d"/")

  # Change into the extracted directory
  cd "$dir_name"

  ./configure && sudo make install

  # cleanup
  cd /tmp
  rm -rf "$dir_name" && rm "stow-latest.tar.gz"
  cd "${current_dir}"
}

# Loop through the arguments
for arg in "$@"; do
  if [ "$arg" == "--dev" ]; then
    dev=true
  elif [ "$arg" == "--optional" ]; then
    dev=true
  elif [ "$arg" == "--install-only" ]; then
    install_only=true
  elif [ "$arg" == "--stow-only" ]; then
    stow_only=true
  fi
done

function add() {
  rm -r "$2" || true
  ln -s "$1" "$2"
}

# snippets
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  vscode_snippets_path="$HOME/.config/Code/User/snippets"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  vscode_snippets_path="$HOME/Library/Application Support/Code/User/snippets"
else
  echo "OS type unknown. Exiting."
  exit 1
fi
mkdir -p "$(dirname "${vscode_snippets_path}")"
add "$ROOT_DIR/stow/common/dot-config/nvim/snippets" "${vscode_snippets_path}"

cd "$ROOT_DIR"

if ! command -v stow >/dev/null 2>&1; then
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    install_stow_debian
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    if ! [ -x "$(command -v brew)" ]; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install stow
  else
    echo "Unsupported OS"
    exit 1
  fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  stow_version=$(stow --version | awk 'NR==1{print $NF}')
  min_stow_version="2.4.0"

  # Compare versions
  if [ "$(printf '%s\n' "$stow_version" "$min_stow_version" | sort -V | head -n1)" = "$stow_version" ] && [ "$stow_version" != "$min_stow_version" ]; then
    echo "Your stow version ($stow_version) is lower than $min_stow_version."
    echo "Installing from tarfile"
    install_stow_debian
  fi
fi

# Stow platform-specific prefix to run stow
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  prefix="debian"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  prefix="macos"
  echo '\.DS_Store' >"$HOME/.stow-global-ignore"
else
  echo "Unsupported OS"
  exit 1
fi

if [[ $install_only != true ]]; then
  cd stow
  # Stow common config
  stow --dotfiles -t ~ common
  # Stow platform specific stuff
  stow --dotfiles -t ~ "${prefix}"

  cd ..
fi

# Private submodule install
SUBMODULE_PATH="dotfiles_private"
# Check if the submodule is not empty
if [[ -n "$(ls -A ${SUBMODULE_PATH})" ]]; then
  echo "Private submodule is available. Installing..."
  submodule_args=()
  if [[ $install_only == true ]]; then
    submodule_args+=("--install-only")
  fi
  if [[ $stow_only == true ]]; then
    submodule_args+=("--stow-only")
  fi
  "${SUBMODULE_PATH}/scripts/install.sh" "${submodule_args[@]}"
else
  echo "Private submodule is not cloned. Skipping installation."
fi

if [[ $stow_only != true ]]; then
  # Platform-specific config install
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    "${SCRIPT_DIR}/debian/install_min.sh"
    if [[ $dev == true ]]; then
      "${SCRIPT_DIR}/debian/install.sh" --optional
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    "${SCRIPT_DIR}/macos/install.sh"
  else
    echo "Unsupported OS"
    exit 1
  fi
fi
