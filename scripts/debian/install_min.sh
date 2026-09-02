#!/bin/bash
set -e
set -x

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/common.sh"

function command_exists() {
  command -v "$1" &>/dev/null
}

function package_installed() {
  dpkg --verify "$1" 2>/dev/null
}

function uncomment_line() {
  # Uses sed to uncomment a line containing a string
  file_path=$1
  string=$2
  sed -i "s/^#*\($string\)/\1/" $file_path
}

function install_nvim_source() {
  branch_str="--branch stable"
  if [ -n "$1" ]; then
    branch_str="--branch $1"
  fi
  sudo apt-get install ninja-build gettext cmake unzip curl -y
  cd /tmp && rm -rf neovim && git clone https://github.com/neovim/neovim.git $branch_str --single-branch
  cd neovim
  if [ "$1" == "master" ]; then
    # don't use latest stuff which breaks highlights
    git reset --hard 17f3a3a
  fi
  make CMAKE_BUILD_TYPE=RelWithDebInfo
  sudo make install
  cd .. && rm -rf neovim
}

function install_nvim_tarball() {
  nvim_download_path=/tmp/nvim-linux64.tar.gz
  nvim_target=/opt/nvim
  architecture=$(uname -m)
  if [[ "$architecture" == "aarch64" ]]; then
    # I don't know why neovim devs do it but they force aarch64 build to be named arm64
    architecture="arm64"
  fi
  curl -Lo "$nvim_download_path" https://github.com/neovim/neovim/releases/latest/download/nvim-linux-"${architecture}".tar.gz
  sudo rm -rf "${nvim_target}"
  sudo mkdir -p "${nvim_target}"
  sudo tar -C "${nvim_target}" --strip-components=1 -xzf "$nvim_download_path"
  rm -rf "$nvim_download_path"
  if ! "${nvim_target}/bin/nvim" --version; then
    echo "nvim binary in ${nvim_target}/bin cannot be opened. Install from nvim tarball failed"
    sudo rm -rf "${nvim_target}"
    return 1
  fi
  if ! grep -Fxq "export PATH=\"\$PATH:${nvim_target}/bin\"" "$HOME/.zshrc"; then
    echo "export PATH=\"\$PATH:${nvim_target}/bin\"" >>$HOME/.zshrc
  fi
  export PATH="$PATH:${nvim_target}/bin"
}

function install_node() {
  installed=false
  if ! [ -x "$(command -v nvm)" ]; then
    echo "Installing nvm."
    local auth_header=()
    if [ -n "${GITHUB_TOKEN:-}" ]; then
      auth_header=(-H "Authorization: Bearer $GITHUB_TOKEN")
    fi
    LATEST_NVM_VERSION=$(curl -s "${auth_header[@]}" "https://api.github.com/repos/nvm-sh/nvm/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+')
    nvm_install_command="wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v${LATEST_NVM_VERSION}/install.sh | bash"
    zsh -c "$nvm_install_command" || eval "$nvm_install_command"
    # load nvm
    NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
    export NVM_DIR
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
    # add nvm to .zshrc with string does not exists after the installation
    if ! grep -Fxq 'export NVM_DIR="$HOME/.nvm"' "$HOME/.zshrc"; then
      tee -a "$HOME/.zshrc" >/dev/null <<'EOT'
# Load nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
EOT
    fi
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
    installed=true
  fi
  if [[ $(lsb_release -cs) == "bionic" ]]; then
    nvm install 16
  else
    nvm install --lts
  fi
  if [ "$installed" = true ]; then
    echo "Please source ~/.zshrc or ~/.bashrc"
  fi
}

function install_delta() {
  if ! [ -x "$(command -v delta)" ]; then
    echo "Installing delta."
    local auth_header=()
    if [ -n "${GITHUB_TOKEN:-}" ]; then
      auth_header=(-H "Authorization: Bearer $GITHUB_TOKEN")
    fi
    LATEST_DELTA_VERSION=$(curl -s "${auth_header[@]}" "https://api.github.com/repos/dandavison/delta/releases/latest" | grep -Po '"tag_name": "\K[0-9.]+')
    wget -O /tmp/delta.deb "https://github.com/dandavison/delta/releases/download/${LATEST_DELTA_VERSION}/git-delta_${LATEST_DELTA_VERSION}_$(dpkg --print-architecture).deb" && sudo apt install -y /tmp/delta.deb && rm -f /tmp/delta.deb
  fi
}

function install_gh() {
  if ! [ -x "$(command -v gh)" ]; then
    local auth_header=()
    if [ -n "${GITHUB_TOKEN:-}" ]; then
      auth_header=(-H "Authorization: Bearer $GITHUB_TOKEN")
    fi
    LATEST_GH_VERSION=$(curl -s "${auth_header[@]}" "https://api.github.com/repos/cli/cli/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+')
    wget -O /tmp/gh.deb "https://github.com/cli/cli/releases/download/v${LATEST_GH_VERSION}/gh_${LATEST_GH_VERSION}_linux_$(dpkg --print-architecture).deb" && sudo apt install -y /tmp/gh.deb && rm -f /tmp/gh.deb
    echo "Optionally run 'gh auth login'"
  fi
}

function update_git() {
  # need at least git 2.31
  version=$(git --version | tr -d -c 0-9.)
  major=$(echo "$version" | cut -d. -f1)
  minor=$(echo "$version" | cut -d. -f2)

  if [ "$major" -lt 2 ] || { [ "$major" -eq 2 ] && [ "$minor" -lt 31 ]; }; then
    if [ "${distro_name:-}" = "Ubuntu" ]; then
      echo "Updating git to the latest version..."
      sudo apt-get install -y software-properties-common
      sudo add-apt-repository ppa:git-core/ppa -y
      sudo apt-get update
      sudo apt-get install --upgrade git -y
    fi
  else
    echo "Git version $version is sufficient."
  fi
}

function install_rust_tree_sitter() {
  install_rust
  $HOME/.cargo/bin/cargo install tree-sitter-cli
}

function install_nvim_binary() {
  branch="stable"
  if [ -n "$1" ]; then
    branch="$1"
  fi
  if [[ "$branch" == "stable" && ( "$(uname -m)" == "x86_64" || "$(uname -m)" == "arm64"|| "$(uname -m)" == "aarch64" ) ]]; then
    install_nvim_tarball || install_nvim_source $branch
  else
    install_nvim_source $branch
  fi
  install_node
  update_git
  sudo apt install libreadline-dev -y   # for hererocks
  sudo apt install libmagickwand-dev -y # for image.nvim
}

function install_zoxide() {
  if ! command -v zoxide >/dev/null 2>&1; then
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
  fi
  grep -qxF 'eval "$(zoxide init zsh)"' $HOME/.zshrc || echo 'eval "$(zoxide init zsh)"' >>$HOME/.zshrc
}

function install_yazi_source() {
  sudo test || true
  install_rust
  if ! command -v rustc >/dev/null 2>&1; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  fi
  cd /tmp && rm -rf yazi && git clone https://github.com/sxyazi/yazi.git
  cd yazi
  highest_tag=$(get_highest_tag_version)
  git checkout $highest_tag

  $HOME/.cargo/bin/cargo build --release
  sudo cp ./target/release/yazi /usr/local/bin/
  cd .. && rm -rf yazi

  if ! grep -Fxq 'function ya() {' $HOME/.zshrc; then
    tee -a $HOME/.zshrc >/dev/null <<'EOT'
function ya() {
  tmp="$(mktemp -t "yazi-cwd.XXXXX")"
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}
EOT
  fi
}

function install_conda() {
  # set up miniconda
  if ! [ -x "$(command -v conda)" ]; then
    mkdir -p ~/miniconda3
    wget "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(uname --machine).sh" -O ~/miniconda3/miniconda.sh
    bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
    rm -rf ~/miniconda3/miniconda.sh
  fi

  git clone https://github.com/esc/conda-zsh-completion ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/conda-zsh-completion
  conda init zsh
  conda config --set auto_activate_base false
  sed -i 's/git-auto-fetch)/git-auto-fetch conda-zsh-completion)/g' $HOME/.zshrc
  # check if conda-zsh-completion is now somewhere in $HOME/.zshrc
  if ! grep -q "conda-zsh-completion" $HOME/.zshrc; then
    echo "conda-zsh-completion was not added successfully to $HOME/.zshrc"
    exit 1
  fi
}

function install_direnv() {
  if ! [ -x "$(command -v direnv)" ]; then
    curl -sfL https://direnv.net/install.sh | bash
    grep -Fxq 'eval "$(direnv hook zsh)"' "$HOME/.zshrc" || echo 'eval "$(direnv hook zsh)"' >>"$HOME/.zshrc"
  fi
}

if [[ ! $# -eq 0 ]]; then
  if [[ $1 == "--install-nvim" ]]; then
    echo "Installing nvim binary..."
    install_nvim_binary stable
    exit 0
  elif [[ $1 == "--install-nvim-dev" ]]; then
    echo "Installing nvim binary from git dev branch..."
    install_nvim_binary master
    exit 0
  elif [[ $1 == "--install-node" ]]; then
    echo "Installing node js over nvm..."
    install_node
    exit 0
  elif [[ $1 == "--install-cargo" ]]; then
    echo "Installing rust and cargo..."
    install_rust
    exit 0
  elif [[ $1 == "--update-git" ]]; then
    echo "Updating git if necessary..."
    update_git
    exit 0
  elif [[ $1 == "--install-yazi" ]]; then
    echo "Installing yazi..."
    install_yazi_source
    exit 0
  elif [[ $1 == "--install-conda" ]]; then
    echo "Installing conda..."
    install_conda
    exit 0
  else
    echo "Option \"$1\" not recognized."
    exit 1
  fi
fi

# --- MAIN ---
sudo apt update
sudo apt install tmux curl wget locales lsb-release zsh xclip unzip python3-venv fd-find ccache git imagemagick pipx libglib2.0-bin vim zsh trash-cli -y
# for thefuck
sudo apt install python3-dev python3-pip python3-setuptools -y
# symlink fdfind as fd
mkdir -p "$HOME/.local/bin"
if command -v fdfind >/dev/null 2>&1; then
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi

sudo apt install ripgrep -y || true

# run set_up_common.sh
"$SCRIPT_DIR/../set_up_common.sh"

if ! grep -q "unsetopt BEEP" $HOME/.zshrc; then
  tee -a $HOME/.zshrc >/dev/null <<'EOT'
if command -v nvim &> /dev/null; then
  alias vim=nvim
  export EDITOR=nvim
fi
unsetopt BEEP
PROMPT="%(?:%{$fg_bold[green]%}➜ :%{$fg_bold[red]%}➜ )"
PROMPT+=' %{$fg[cyan]%}%~%{$reset_color%} $(git_prompt_info)'
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export PATH=$PATH:$HOME/.local/bin
export PATH="/usr/lib/ccache:$PATH"
eval $(thefuck --alias doit)
EOT

  # set plugin variables before sourcing oh-my-zsh
  ex -s $HOME/.zshrc <<\IN
/source \$ZSH\/oh-my-zsh.sh/i
# don't underline the paths with zsh-syntax-highlighting
(( ${+ZSH_HIGHLIGHT_STYLES} )) || typeset -A ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[path]=none
ZSH_HIGHLIGHT_STYLES[path_prefix]=none

# zsh-expand
export ZPWR_EXPAND_BLACKLIST=(ls vim grep z zi)
export ZPWR_EXPAND_TO_HISTORY=true # expand to history also on enter

.
wq
IN
  sed -i 's/plugins=(git)/plugins=(git ubuntu zsh-syntax-highlighting zsh-expand zsh-vim-mode git-auto-fetch)/g' $HOME/.zshrc
  sed -i '/mode auto/s/^# //g' $HOME/.zshrc
fi

sudo locale-gen en_US
sudo locale-gen en_US.UTF-8

# set up thefuck
if ! command -v thefuck &>/dev/null; then
  pipx install thefuck
fi

# set up nvim
if ! [ -x "$(command -v nvim)" ]; then
  echo 'nvim is not installed. installing'
  install_nvim_binary stable
  # install plugins
  until nvim --headless "+Lazy! install" +qa; do
    echo "Retrying nvim plugin installation..."
    sleep 1
  done
fi

# set up fzf for zsh
if [ ! -d "$HOME/.fzf" ]; then
  git clone --depth 1 https://github.com/junegunn/fzf.git $HOME/.fzf
  $HOME/.fzf/install --key-bindings --completion --update-rc --no-bash
fi

# install git lfs
if ! command_exists git-lfs; then
  curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash && sudo apt-get install git-lfs && git lfs install
fi

install_node

install_zoxide

install_direnv

install_delta

install_gh
