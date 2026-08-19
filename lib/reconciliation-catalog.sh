#!/usr/bin/env bash
# The declarative source of truth for machine reconciliation. Keep this file
# data-oriented: the installer owns the lifecycle implementation.

readonly CATALOG_PACKAGES=(
  atuin
  eza
  git
  lazygit
  nvim
  starship
  tmux
  wezterm
  yazi
  zsh
)

readonly CATALOG_REQUIRED_FORMULAE=(
  stow
  zsh
  tmux
  starship
  eza
  bat
  fd
  fzf
  ripgrep
  zoxide
  sesh
  yazi
  neovim
  git
  git-delta
  lazygit
  atuin
)

# A full reconciliation includes Yazi preview support.
readonly CATALOG_YAZI_PREVIEW_FORMULAE=(
  ffmpeg-full
  imagemagick-full
  poppler
  resvg
  sevenzip
  jq
)

readonly CATALOG_KEG_ONLY_FORMULAE=(
  ffmpeg-full
  imagemagick-full
)

readonly CATALOG_FONT_CASKS=(
  font-maple-mono-nf-cn
  font-proggy-clean-tt-nerd-font
  font-fantasque-sans-mono-nerd-font
  font-symbols-only-nerd-font
)

readonly CATALOG_TPM_REPO="https://github.com/tmux-plugins/tpm"

# Preserve the existing order of package-specific automated reconciliation.
readonly CATALOG_AUTOMATED_RECONCILIATION_PACKAGES=(
  zsh
  tmux
  yazi
)

catalog_package_description() {
  case "$1" in
    atuin) printf '%s\n' 'shell history config, Catppuccin Mocha themes' ;;
    eza) printf '%s\n' '`ls` replacement colour theme' ;;
    git) printf '%s\n' '`config` (diff/merge defaults, delta pager — no identity), global `ignore`' ;;
    lazygit) printf '%s\n' 'git UI theme (Catppuccin Mocha), delta diff renderer' ;;
    nvim) printf '%s\n' 'LazyVim-based editor config, `lazy-lock.json`, lazy.nvim-managed plugins' ;;
    starship) printf '%s\n' 'prompt theme, custom git-remote and worktree modules' ;;
    tmux) printf '%s\n' '`tmux.conf`, `bin/tmux-sessionizer.sh`, TPM-managed plugins' ;;
    wezterm) printf '%s\n' 'terminal config, key tables, status line' ;;
    yazi) printf '%s\n' 'file manager theme, `ya pkg`-managed flavors' ;;
    zsh) printf '%s\n' 'shell config split into `.zshenv`, `.zprofile`, `.zshrc`, aliases, fzf, plugins, and prompt' ;;
    *) return 1 ;;
  esac
}

catalog_formula_description() {
  case "$1" in
    stow) printf '%s\n' 'installs this repo into `$HOME`' ;;
    zsh) printf '%s\n' 'the shell itself' ;;
    tmux) printf '%s\n' 'terminal multiplexer' ;;
    starship) printf '%s\n' 'the prompt (`prompt.zsh`)' ;;
    eza) printf '%s\n' '`ls` / `ll` / `la` / `tree` aliases' ;;
    bat) printf '%s\n' '`cat` alias, `$MANPAGER`, fzf preview' ;;
    fd) printf '%s\n' '`$FZF_DEFAULT_COMMAND`, the tmux sessionizer' ;;
    fzf) printf '%s\n' '`Ctrl-T` / `Alt-C`, sesh pickers' ;;
    ripgrep) printf '%s\n' '`grep` alias' ;;
    zoxide) printf '%s\n' 'smart `cd` (`.zshrc`)' ;;
    sesh) printf '%s\n' 'session picker — `Esc-s` in zsh, `prefix K` in tmux' ;;
    yazi) printf '%s\n' 'the `y` function and `prefix C-y` popup; `ya pkg` installs its flavors' ;;
    neovim) printf '%s\n' '`$EDITOR` / `$VISUAL`, `vim` alias, tmux config-edit menu' ;;
    git) printf '%s\n' 'version control' ;;
    git-delta) printf '%s\n' '`core.pager` / `interactive.diffFilter`' ;;
    lazygit) printf '%s\n' 'the `lg` alias (`aliases.zsh`)' ;;
    atuin) printf '%s\n' '`Ctrl-R` history search (`.zshrc`)' ;;
    *) return 1 ;;
  esac
}

# Fixed lifecycle types. The installer maps these names to its implementation.
catalog_package_automated_steps() {
  case "$1" in
    tmux) printf '%s\n' 'install-tpm' ;;
    yazi) printf '%s\n' 'install-yazi-flavors' ;;
    zsh) printf '%s\n' 'link-zshenv' ;;
  esac
}

catalog_user_followups() {
  printf '%s\n' \
    'Start a new shell (`exec zsh`). The zsh plugins clone themselves on first run.' \
    'Inside tmux, press `prefix + I` (`C-s` then `Shift-i`) to install the tmux plugins.' \
    'Set your terminal font to `Maple Mono NF CN` (or another installed Nerd Font).'
}

catalog_machine_local_state() {
  printf '%s\t%s\n' \
    '~/.gitconfig' 'Git identity, credential helpers, signing keys, and machine-specific includes remain untracked.' \
    '~/.config/zsh/secrets.zsh' 'API keys and tokens remain gitignored machine-local state.' \
    '~/.zshenv' 'A real file is preserved rather than overwritten because it can contain machine-specific settings.'
}
