#!/bin/bash
set -e
set -x

SCRIPT_DIR=$(dirname "$0")

source "$SCRIPT_DIR/common.sh"

# Initialize a flag
optional_provided=false

# Loop through the arguments
for arg in "$@"; do
  if [ "$arg" == "--optional" ]; then
    optional_provided=true
    break
  fi
done

function setup_nerdfont() {
  mkdir -p ~/.local/share/fonts
  git clone https://github.com/epk/SF-Mono-Nerd-Font.git /tmp/SF-Mono-Nerd-Font
  cp /tmp/SF-Mono-Nerd-Font/*.otf ~/.local/share/fonts/
  rm -rf /tmp/SF-Mono-Nerd-Font
  fc-cache -f
}

function install_starship() {
  curl -sS https://starship.rs/install.sh | sh -s -- -y
    cat << 'EOF' >> ~/.zshrc

eval "$(starship init zsh)"
[[ ! -f ~/.config/starship-transient.zsh ]] || source ~/.config/starship-transient.zsh
EOF
}

function install_sublimetext() {
  if ! [ -x "$(command -v subl)" ]; then
    wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/sublimehq-archive.gpg >/dev/null
    echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list
    sudo apt update
    sudo apt install sublime-text -y
  fi
}

function install_spotify() {
  if ! [ -x "$(command -v spotify)" ]; then
    curl -sS https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
    echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
    sudo apt-get update && sudo apt-get install spotify-client -y || echo "Spotify installation failed. Consider installing outside of apt."
  fi
}

function install_flatpak() {
  if ! [ -x "$(command -v flatpak)" ]; then
    sudo apt install flatpak -y
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  fi
}

function install_open_any_terminal() {
  # ubuntu specific
  if [ "$distro_name" = "Ubuntu" ]; then
    return
  fi
  # to open from nautilus with default terminal
  # if /home/jorbik/.local/share/nautilus-python/extensions/nautilus_open_any_terminal.py does not exist
  if [ ! -f ~/.local/share/nautilus-python/extensions/nautilus_open_any_terminal.py ]; then
    cwd=$(pwd)
    cd /tmp
    sudo apt install gettext -y
    git clone https://github.com/Stunkymonkey/nautilus-open-any-terminal.git
    cd nautilus-open-any-terminal
    make

    make install schema # User install
    default_terminal=ghostty
    gsettings set com.github.stunkymonkey.nautilus-open-any-terminal terminal ${default_terminal}
    sudo apt install python3-nautilus -y
    echo "To make the 'Open with ${default_terminal}' work restart nautilus: 'nautilus -q'"
    cd "$cwd"
  fi
}

function install_ghostty_source() {
  # based on https://ghostty.org/docs/install/build
  sudo rm -rf /tmp/ghostty
  rm -rf /tmp/zig
  # dependencies
  sudo apt install libgtk-4-dev libadwaita-1-dev git
  # currently ghostty depends on zig 0.13
  zig_version=0.13.0
  # download zig to temp
  wget -O /tmp/zig.tar "https://ziglang.org/download/0.13.0/zig-linux-$(uname -m)-${zig_version}.tar.xz" && mkdir -p /tmp/zig && tar -xf /tmp/zig.tar -C /tmp/zig
  zig_path=/tmp/zig/zig-linux-$(uname -m)-${zig_version}
  # download ghostty
  git clone https://github.com/ghostty-org/ghostty /tmp/ghostty
  cwd=$(pwd)
  cd /tmp/ghostty
  highest_tag=$(get_highest_tag_version)
  git checkout "$highest_tag"

  # build and install
  sudo env PATH="$PATH:$zig_path" zig build -p /usr -Doptimize=ReleaseFast

  # cleanup
  sudo rm -rf /tmp/ghostty
  rm -rf /tmp/zig
  cd "$cwd"
}

function install_ghostty_ubuntu_package() {
  if ! [ -x "$(command -v ghostty)" ]; then
    LATEST_VERSION=$(curl -s "https://api.github.com/repos/mkasberg/ghostty-ubuntu/releases/latest" | grep -Po '"tag_name": "\K[^"]+')
    wget -O /tmp/ghostty.deb "https://github.com/mkasberg/ghostty-ubuntu/releases/download/${LATEST_VERSION}/ghostty_${LATEST_VERSION//-ppa/.ppa}_$(dpkg --print-architecture)_$(lsb_release -rs).deb" && sudo apt -f install -y /tmp/ghostty.deb || return 1
  fi
}

function install_ghostty() {
  if [ "$distro_name" = "Ubuntu" ]; then
    install_ghostty_ubuntu_package || install_ghostty_source
  else
    install_ghostty_source
  fi
}

function install_trdop() {
  cwd=$(pwd)
  mkdir -p ~/.local/bin/
  cd ~/.local/bin/
  git clone https://github.com/noctuid/tdrop.git
  echo "Add custom hotkey in Ubuntu to activate terminal with tdrop"
  echo "Command is: '$HOME/.local/bin/tdrop/tdrop -mta -h 100% <terminal_name>'"
  echo "This will work work with nvidia drivers on the latest Ubuntu"
  # installing tdrop dependencies
  sudo apt install xdotool gawk -y
  cd "$cwd"
}

function install_wezterm() {
  curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
  echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list
  sudo apt update
  sudo apt install wezterm -y

  if [ "$distro_name" = "Ubuntu" ] && [[ ! -e "$HOME/.local/bin/tdrop/tdrop" ]]; then
    # ubuntu specific - set up tdrop for wezterm activation with hotkey
    install_trdop
  fi
}

setup_nerdfont
install_sublimetext
install_ghostty
install_open_any_terminal
install_starship
sudo apt install copyq -y

if [ "$distro_name" = "Ubuntu" ]; then
  # disable meta+number key bindings - it interferes with wezterm
  gsettings set org.gnome.shell.extensions.dash-to-dock hot-keys false || true
  for i in $(seq 1 9); do gsettings set org.gnome.shell.keybindings "switch-to-application-${i}" '[]' || true; done
fi

if [ "$optional_provided" == true ]; then
  echo "--optional was provided, installing optional tools."
  install_flatpak
  install_spotify
fi
