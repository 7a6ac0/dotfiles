#!/usr/bin/env bash
#
# Bootstrap these dotfiles on macOS.
#
# Idempotent: safe to re-run on an already-configured machine.
#
#   ./install.sh                        full install
#   DOTFILES_SKIP_BREW=1 ./install.sh   re-stow only, skip Homebrew
#
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

readonly TPM_REPO="https://github.com/tmux-plugins/tpm"
readonly TPM_DIR="$HOME/.config/tmux/plugins/tpm"

readonly BACKUP_ROOT="$HOME/.dotfiles-backup"

# Set on the first backup of a run; all of that run's rescues share the directory.
backup_dir=""

readonly PACKAGES=(atuin eza nvim starship tmux wezterm yazi zsh)

# Required by the configs in this repo.
readonly BREW_FORMULAE=(
  stow     # installs this repo into $HOME
  zsh      # the shell itself
  tmux     # terminal multiplexer
  starship # prompt
  eza      # ls/ll/la/tree aliases
  bat      # cat alias, MANPAGER, fzf preview
  fd       # FZF_DEFAULT_COMMAND, sessionizer
  fzf      # fuzzy finder, sessionizer
  ripgrep  # grep alias
  zoxide   # smart cd
  sesh     # session picker (prefix K, Esc-s)
  yazi     # y(), prefix C-y
  neovim   # $EDITOR / $VISUAL
  git      # version control
  lazygit  # git UI
  atuin    # shell history manager
)

# Optional: yazi's preview backends for media, PDFs, SVGs and archives.
readonly BREW_FORMULAE_OPTIONAL=(
  ffmpeg-full
  imagemagick-full
  poppler
  resvg
  sevenzip
  jq
)

# Subset of the above that brew keeps keg-only and will not link on its own.
readonly BREW_FORMULAE_KEG_ONLY=(
  ffmpeg-full
  imagemagick-full
)

# Nerd Fonts — the prompt, tmux status line and eza icons need them.
readonly BREW_CASKS=(
  font-maple-mono-nf-cn
  font-proggy-clean-tt-nerd-font
  font-fantasque-sans-mono-nerd-font
  font-symbols-only-nerd-font
)

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

check_platform() {
  [[ "$(uname -s)" == "Darwin" ]] ||
    die "these dotfiles target macOS (.zprofile hardcodes /opt/homebrew)"
  command -v brew >/dev/null 2>&1 ||
    die "Homebrew not found — install it first: https://brew.sh"
}

install_packages() {
  if [[ -n "${DOTFILES_SKIP_BREW:-}" ]]; then
    log "DOTFILES_SKIP_BREW set — skipping Homebrew"
    return
  fi

  log "Installing required formulae"
  brew install "${BREW_FORMULAE[@]}"

  log "Installing optional yazi preview backends"
  brew install "${BREW_FORMULAE_OPTIONAL[@]}"

  # Both are :versioned_formula, so brew installs them keg-only and leaves them
  # unlinked — yazi's video and image previews need them on PATH.
  log "Linking keg-only preview backends"
  brew link "${BREW_FORMULAE_KEG_ONLY[@]}" --force --overwrite

  log "Installing Nerd Fonts"
  brew install --cask "${BREW_CASKS[@]}"
}

# .zshrc points compinit and HISTFILE at these; neither creates its parent.
create_xdg_dirs() {
  log "Creating XDG cache/state directories"
  mkdir -p "$HOME/.cache/zsh" "$HOME/.local/state/zsh" "$HOME/.local/bin"
}

# Every package in this repo installs to ~/.config/<package>.
config_target() { printf '%s/.config/%s' "$HOME" "$1"; }

# Where that target must point once the package is stowed.
package_source() { printf '%s/%s/.config/%s' "$DOTFILES_DIR" "$1" "$1"; }

# stow refuses to write over a real file or directory, so anything already
# sitting on a package's target is moved aside first. A machine with a
# hand-rolled ~/.config keeps its old config instead of blocking the install.
#
# Links this repo already owns are left alone — otherwise every re-run would
# manufacture a backup of itself and `stow --restow` would have nothing to do.
backup_conflicts() {
  local pkg target

  for pkg in "${PACKAGES[@]}"; do
    target="$(config_target "$pkg")"

    # -e is false for a broken symlink, so -L has to be tested separately.
    [[ -e "$target" || -L "$target" ]] || continue

    # -ef compares inodes through symlinks: true only when this exact package
    # is what the target already resolves to.
    [[ "$target" -ef "$(package_source "$pkg")" ]] && continue

    if [[ -z "$backup_dir" ]]; then
      backup_dir="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
      mkdir -p "$backup_dir" || die "cannot create backup directory $backup_dir"
    fi

    log "Backing up $target -> $backup_dir/$pkg"
    mv "$target" "$backup_dir/$pkg" || die "could not move $target aside"
  done

  if [[ -n "$backup_dir" ]]; then
    warn "existing config was moved to $backup_dir"
  fi
}

stow_packages() {
  command -v stow >/dev/null 2>&1 || die "stow not found — run without DOTFILES_SKIP_BREW"

  local pkg
  for pkg in "${PACKAGES[@]}"; do
    log "Stowing $pkg -> \$HOME"
    if ! stow --restow --target="$HOME" --dir="$DOTFILES_DIR" "$pkg"; then
      die "stow failed for '$pkg' — move the conflicting path listed above aside, then re-run"
    fi
  done
}

# zsh only auto-reads ~/.zshenv, and that file is what sets ZDOTDIR.
# Stow cannot create this hop, so it is done by hand.
link_zshenv() {
  local target="$HOME/.config/zsh/.zshenv"
  local link="$HOME/.zshenv"

  if [[ -e "$link" && ! -L "$link" ]]; then
    warn "$link is a real file, not a symlink — leaving it alone"
    warn "back it up and re-run, or add 'export ZDOTDIR=\"\$HOME/.config/zsh\"' to it manually"
    return
  fi

  if [[ -L "$link" && "$(readlink "$link")" == "$target" ]]; then
    log "$link already linked"
    return
  fi

  log "Linking $link -> $target"
  ln -sfn "$target" "$link"
}

install_tpm() {
  if [[ -d "$TPM_DIR" ]]; then
    log "TPM already present"
    return
  fi
  log "Cloning TPM into $TPM_DIR"
  git clone --depth=1 "$TPM_REPO" "$TPM_DIR"
}

# yazi's flavor is a `ya pkg` clone pinned in package.toml, not tracked source.
install_yazi_deps() {
  if ! command -v ya >/dev/null 2>&1; then
    warn "ya not found — skipping yazi flavors (install yazi, then run 'ya pkg install')"
    return
  fi
  log "Installing yazi flavors from package.toml"
  ya pkg install
}

main() {
  check_platform
  install_packages
  create_xdg_dirs
  backup_conflicts
  stow_packages
  link_zshenv
  install_tpm
  install_yazi_deps

  cat <<'EOF'

Done. Remaining manual steps:

  1. Start a new shell (exec zsh). The zsh plugins clone themselves on first run.
  2. Inside tmux, press prefix + I (C-s then Shift-i) to install the tmux plugins.
  3. Set your terminal font to "Maple Mono NF CN" (or another installed Nerd Font).

EOF
}

main "$@"
