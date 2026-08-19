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

# shellcheck source=.automation/reconciliation-catalog.sh
source "$DOTFILES_DIR/.automation/reconciliation-catalog.sh"

readonly BACKUP_ROOT="$HOME/.dotfiles-backup"

# Set on the first backup of a run; all of that run's rescues share the directory.
backup_dir=""

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

# Names out of "$@" that brew has not installed yet, one per line. "$1" is the
# list to check against: formula or cask.
#
# Handing brew something it already has only earns a "already installed and
# up-to-date" warning plus reinstall advice, which on a re-run buries the lines
# that matter. Filtering first keeps the output to actual work.
missing_packages() {
  local kind="$1" installed pkg
  shift

  # Newline-delimited on both ends so the match below cannot hit a substring.
  installed=$'\n'"$(brew list "--$kind" -1)"$'\n'

  for pkg in "$@"; do
    [[ "$installed" == *$'\n'"$pkg"$'\n'* ]] || printf '%s\n' "$pkg"
  done
}

install_missing() {
  local kind="$1" label="$2"
  shift 2

  local missing=() pkg
  while IFS= read -r pkg; do
    missing+=("$pkg")
  done < <(missing_packages "$kind" "$@")

  if [[ ${#missing[@]} -eq 0 ]]; then
    log "$label already installed"
    return
  fi

  log "Installing $label: ${missing[*]}"
  if [[ "$kind" == cask ]]; then
    brew install --cask "${missing[@]}"
  else
    brew install "${missing[@]}"
  fi
}

# Both keg-only formulae are :versioned_formula, so brew installs them unlinked
# — yazi's video and image previews need them on PATH.
link_keg_only() {
  local prefix pkg
  prefix="$(brew --prefix)"

  for pkg in "${CATALOG_KEG_ONLY_FORMULAE[@]}"; do
    # brew records a link as a symlink here; calling `brew link` on a keg that
    # already has one just prints "Already linked".
    [[ -L "$prefix/var/homebrew/linked/$pkg" ]] && continue

    log "Linking keg-only $pkg"
    brew link "$pkg" --force --overwrite
  done
}

install_packages() {
  if [[ -n "${DOTFILES_SKIP_BREW:-}" ]]; then
    log "DOTFILES_SKIP_BREW set — skipping Homebrew"
    return
  fi

  install_missing formula "required formulae" "${CATALOG_REQUIRED_FORMULAE[@]}"
  install_missing formula "Yazi preview backends" "${CATALOG_YAZI_PREVIEW_FORMULAE[@]}"
  link_keg_only
  install_missing cask "Nerd Fonts" "${CATALOG_FONT_CASKS[@]}"
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

  for pkg in "${CATALOG_PACKAGES[@]}"; do
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
  for pkg in "${CATALOG_PACKAGES[@]}"; do
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
  local tpm_dir="$HOME/.config/tmux/plugins/tpm"

  if [[ -d "$tpm_dir" ]]; then
    log "TPM already present"
    return
  fi
  log "Cloning TPM into $tpm_dir"
  git clone --depth=1 "$CATALOG_TPM_REPO" "$tpm_dir"
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

run_package_automated_reconciliation() {
  local pkg step

  for pkg in "${CATALOG_AUTOMATED_RECONCILIATION_PACKAGES[@]}"; do
    while IFS= read -r step; do
      case "$step" in
        install-tpm) install_tpm ;;
        install-yazi-flavors) install_yazi_deps ;;
        link-zshenv) link_zshenv ;;
        *) die "unknown automated reconciliation step '$step' for '$pkg'" ;;
      esac
    done < <(catalog_package_automated_steps "$pkg")
  done
}

print_user_followups() {
  local followup number=1

  printf '\nDone. Remaining manual steps:\n\n'
  while IFS= read -r followup; do
    printf '  %d. %s\n' "$number" "$followup"
    number=$((number + 1))
  done < <(catalog_user_followups)
  printf '\n'
}

main() {
  check_platform
  install_packages
  create_xdg_dirs
  backup_conflicts
  stow_packages
  run_package_automated_reconciliation
  print_user_followups
}

main "$@"
