# dotfiles

Personal configs: zsh (oh-my-zsh + znap + p10k), tmux (+ sessionizer),
starship, Doom Emacs, and a few small tool configs (zellij, ghostty, kitty,
bat, git, lazygit, ctags).

## Install

```sh
git clone <repo-url> ~/Repos/dotfiles
~/Repos/dotfiles/install.sh
```

`install.sh` symlinks files into place, backing up anything it replaces to
`<name>.pre-dotfiles`.

## Machine-local / private config (not tracked)

- `~/.localrc` — sourced at the end of `zshrc`; work hosts, Perforce env,
  site-specific PATH entries live here.
- `~/.config/tmux/tmux-sessionizer.conf` — project list for the sessionizer;
  seeded from `tmux/tmux-sessionizer.conf.template` on first install.
- `~/.config/doom-local/` — machine/site-local Doom Emacs overlay: every
  `*.el` there loads after the tracked modules, `custom.el` there is used
  as `custom-file`, and a `snippets/` subdir is added to yasnippet. Work
  identity, site paths, and site snippets live here, never in the repo.

## Notes

- kitty themes come from [kitty-themes](https://github.com/dexpota/kitty-themes)
  cloned to `~/.config/kitty/themes` (not tracked here).
- tmux plugins are managed by [tpm](https://github.com/tmux-plugins/tpm):
  `git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm`, then
  prefix + I to install.
