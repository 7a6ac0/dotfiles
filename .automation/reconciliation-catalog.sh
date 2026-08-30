#!/usr/bin/env bash
# The declarative source of truth for machine reconciliation. Keep this file
# data-oriented: the installer owns the lifecycle implementation.
#
# Everything a reconciliation run can install belongs to one selectable item —
# either a managed package or an extra — so the installer can offer the whole
# inventory as a checklist and act on nothing the user turned off.

readonly CATALOG_PACKAGES=(
  atuin
  eza
  git
  herdr
  lazygit
  nvim
  starship
  tmux
  wezterm
  yazi
  zsh
)

# Selectable items that are not Stow packages.
readonly CATALOG_EXTRAS=(
  yazi-previews
  fonts
)

# Installed whatever the selection is: without these the installer cannot do
# its own job — stow places every package, git clones TPM.
readonly CATALOG_CORE_FORMULAE=(
  stow
  git
)

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
  herdr
)

# Order in which package follow-ups read best, which is not catalogue order.
readonly CATALOG_FOLLOWUP_PACKAGES=(
  zsh
  tmux
  herdr
)

catalog_package_description() {
  case "$1" in
    atuin) printf '%s\n' 'shell history config, Catppuccin Mocha themes' ;;
    eza) printf '%s\n' '`ls` replacement colour theme' ;;
    git) printf '%s\n' '`config` (diff/merge defaults, delta pager — no identity), global `ignore`' ;;
    herdr) printf '%s\n' 'agent multiplexer `config.toml`, `plugin-src/agent-elapsed/` sidebar plugin — Catppuccin Mocha, tmux-shaped `Ctrl-s` prefix' ;;
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

catalog_extra_description() {
  case "$1" in
    yazi-previews) printf '%s\n' 'video, image, PDF, SVG and archive previews inside yazi' ;;
    fonts) printf '%s\n' 'the Nerd Font casks the terminal and editor configs assume' ;;
    *) return 1 ;;
  esac
}

# The Homebrew formulae a package needs to behave as configured. A formula that
# two packages both depend on is listed under both; the installer de-duplicates.
catalog_package_formulae() {
  case "$1" in
    atuin) printf '%s\n' atuin ;;
    eza) printf '%s\n' eza ;;
    git) printf '%s\n' git-delta ;;
    herdr) printf '%s\n' herdr ;;
    lazygit) printf '%s\n' lazygit git-delta ;;
    nvim) printf '%s\n' neovim ;;
    starship) printf '%s\n' starship ;;
    tmux) printf '%s\n' tmux fzf fd sesh ;;
    wezterm) ;;
    yazi) printf '%s\n' yazi ;;
    zsh) printf '%s\n' zsh bat eza fd fzf ripgrep zoxide sesh ;;
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
    git) printf '%s\n' 'version control; clones TPM during reconciliation' ;;
    git-delta) printf '%s\n' '`core.pager` / `interactive.diffFilter`' ;;
    herdr) printf '%s\n' 'agent multiplexer; `herdr server` is its background service' ;;
    lazygit) printf '%s\n' 'the `lg` alias (`aliases.zsh`)' ;;
    atuin) printf '%s\n' '`Ctrl-R` history search (`.zshrc`)' ;;
    *) return 1 ;;
  esac
}

# Drops repeats while keeping first-seen order, so a formula claimed by several
# packages reaches brew once.
catalog_unique() { awk '!seen[$0]++'; }

# Every formula a full reconciliation installs, core first.
catalog_all_required_formulae() {
  local pkg
  {
    printf '%s\n' "${CATALOG_CORE_FORMULAE[@]}"
    for pkg in "${CATALOG_PACKAGES[@]}"; do
      catalog_package_formulae "$pkg"
    done
  } | catalog_unique
}

# Fixed lifecycle types. The installer maps these names to its implementation.
catalog_package_automated_steps() {
  case "$1" in
    tmux) printf '%s\n' 'install-tpm' ;;
    yazi) printf '%s\n' 'install-yazi-flavors' ;;
    zsh) printf '%s\n' 'link-zshenv' ;;
    herdr) printf '%s\n' 'link-herdr-plugins' ;;
  esac
}

catalog_package_followups() {
  case "$1" in
    zsh) printf '%s\n' 'Start a new shell (`exec zsh`). The zsh plugins clone themselves on first run.' ;;
    tmux) printf '%s\n' 'Inside tmux, press `prefix + I` (`C-s` then `Shift-i`) to install the tmux plugins.' ;;
    herdr) printf '%s\n' 'Start the herdr server (`brew services start herdr`), then run `herdr` to attach. Where it was already running, `brew services restart herdr` — plugin startup commands only launch with the server.' ;;
  esac
}

catalog_extra_followups() {
  case "$1" in
    fonts) printf '%s\n' 'Set your terminal font to `Maple Mono NF CN` (or another installed Nerd Font).' ;;
  esac
}

# The follow-ups a full reconciliation leaves behind.
catalog_user_followups() {
  local pkg extra

  for pkg in "${CATALOG_FOLLOWUP_PACKAGES[@]}"; do
    catalog_package_followups "$pkg"
  done
  for extra in "${CATALOG_EXTRAS[@]}"; do
    catalog_extra_followups "$extra"
  done
}

catalog_machine_local_state() {
  printf '%s\t%s\n' \
    '~/.gitconfig' 'Git identity, credential helpers, signing keys, and machine-specific includes remain untracked.' \
    '~/.config/zsh/secrets.zsh' 'API keys and tokens remain gitignored machine-local state.' \
    '~/.zshenv' 'A real file is preserved rather than overwritten because it can contain machine-specific settings.'
}
