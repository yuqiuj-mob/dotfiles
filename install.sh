#!/usr/bin/env bash
# Symlink dotfiles into place. Idempotent; existing real files are moved to
# <name>.pre-dotfiles before linking. Machine-local files (~/.localrc,
# ~/.config/tmux/tmux-sessionizer.conf) are seeded, never overwritten.
set -euo pipefail
DOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Platform switch: zsh/zprofile sets PATH via Homebrew on macOS, so catch a
# missing brew here instead of debugging a broken PATH later.
case "$(uname -s)" in
  Darwin)
    [[ -x /opt/homebrew/bin/brew || -x /usr/local/bin/brew ]] ||
      echo "warning: Homebrew not found; PATH setup in zprofile expects it (https://brew.sh)" >&2
    ;;
  Linux)
    ;;
esac

link() {  # link <repo-relative-src> <absolute-dest>
  local src="$DOT/$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" && ! -L "$dest" ]]; then
    mv "$dest" "$dest.pre-dotfiles"
    echo "backed up: $dest -> $dest.pre-dotfiles"
  fi
  ln -sfn "$src" "$dest"
  echo "linked: $dest -> $src"
}

# zsh
link zsh/zshrc      ~/.zshrc
link zsh/zshenv     ~/.zshenv
link zsh/zprofile   ~/.zprofile
link zsh/p10k.zsh   ~/.p10k.zsh

# tmux + sessionizer (conf is machine-local: seeded from template if missing)
link tmux/tmux.conf        ~/.tmux.conf
link tmux/tmux-sessionizer ~/.config/tmux/tmux-sessionizer
[[ -f ~/.config/tmux/tmux-sessionizer.conf ]] ||
  cp "$DOT/tmux/tmux-sessionizer.conf.template" ~/.config/tmux/tmux-sessionizer.conf

# ~/.config
link config/starship.toml      ~/.config/starship.toml
link config/starship-info.toml ~/.config/starship-info.toml
link config/zellij/config.kdl  ~/.config/zellij/config.kdl
link config/ghostty/config     ~/.config/ghostty/config
link config/kitty/kitty.conf   ~/.config/kitty/kitty.conf
link config/bat/config         ~/.config/bat/config
link config/git/ignore         ~/.config/git/ignore
link config/lazygit/config.yml ~/.config/lazygit/config.yml

# doom emacs (machine/site-local overlay lives in ~/.config/doom-local, untracked)
link config/doom ~/.config/doom
mkdir -p ~/.config/doom-local

# misc home dotfiles
link gitconfig ~/.gitconfig
link ctags     ~/.ctags

# ~/.localrc holds machine-local & work config sourced by zshrc; seed empty
[[ -f ~/.localrc ]] || { touch ~/.localrc; echo "seeded empty ~/.localrc"; }

# ~/.gitconfig.local holds machine-local git config (e.g. maintenance repos)
[[ -f ~/.gitconfig.local ]] || { touch ~/.gitconfig.local; echo "seeded empty ~/.gitconfig.local"; }

echo "done."
