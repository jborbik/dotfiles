#!/bin/bash
set -e
set -x

if [ -d ~/.oh-my-zsh ]; then
  echo "oh-my-zsh is installed"
else
  echo "installing oh-my-zsh"
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  echo "Changing default shell, password required"
  sudo chsh -s "$(which zsh)" "$(whoami)" || true
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/plugins/zsh-syntax-highlighting
  git clone https://github.com/MenkeTechnologies/zsh-expand.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/plugins/zsh-expand
  git clone https://github.com/softmoth/zsh-vim-mode "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/plugins/zsh-vim-mode
fi

# auto setup remote for new branches
git config --global --bool push.autoSetupRemote true
# always rebase on pull
git config --global pull.rebase true

git config --global --get user.name >/dev/null || git config --global user.name "Jedrzej Orbik"
git config --global --get user.email >/dev/null || git config --global user.email jborbik@users.noreply.github.com

grep -Fq 'source ~/.aliases' "$HOME/.zshrc" || echo '[ -e ~/.aliases ] && source ~/.aliases' >>"$HOME/.zshrc"
grep -Fxq 'export PATH=$PATH:$HOME/.local/bin' "$HOME/.zshrc" || echo 'export PATH=$PATH:$HOME/.local/bin' >>"$HOME/.zshrc"

if ! grep -qxF 'typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet' "$HOME"/.zshrc; then
  tee -a "$HOME"/.zshrc >/dev/null <<'EOT'
# don't show the warning which happens if direnv loads the .envrc file
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
EOT
fi
mkdir -p ~/.config/direnv
echo '[global]
load_dotenv = true
strict_env = true' >"$HOME"/.config/direnv/direnv.toml
