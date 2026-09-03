#!/usr/bin/env bash
# Black-box tests for the public ./install.sh interface on macOS.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf 'skip: dotfiles installation is supported on macOS only\n'
  exit 0
fi

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_file() { [[ -f "$1" ]] || fail "expected file: $1"; }
assert_directory() { [[ -d "$1" ]] || fail "expected directory: $1"; }
assert_symlink() { [[ -L "$1" ]] || fail "expected symlink: $1"; }
assert_absent() { [[ ! -e "$1" && ! -L "$1" ]] || fail "expected nothing at: $1"; }
assert_contains() { grep -Fq "$2" "$1" || fail "expected '$2' in $1"; }
assert_lacks() { grep -Fq "$2" "$1" && fail "did not expect '$2' in $1"; return 0; }

new_environment() {
  local name="$1"
  CURRENT_ROOT="$TEST_ROOT/$name"
  CURRENT_HOME="$CURRENT_ROOT/home"
  CURRENT_BIN="$CURRENT_ROOT/bin"
  CURRENT_LOG="$CURRENT_ROOT/log"
  CURRENT_STATE="$CURRENT_ROOT/brew-state"
  CURRENT_PREFIX="$CURRENT_ROOT/homebrew"

  mkdir -p "$CURRENT_HOME" "$CURRENT_BIN" "$CURRENT_PREFIX"
  : > "$CURRENT_LOG"
  : > "$CURRENT_STATE"
  cp "$ROOT_DIR/.automation/fakes/"* "$CURRENT_BIN/"
  chmod +x "$CURRENT_BIN/"*
}

# Redirecting stdout is also what makes the run non-interactive: without a
# terminal to draw the checklist on, install.sh reconciles every item.
run_install() {
  local output="$1"
  shift
  HOME="$CURRENT_HOME" \
  PATH="$CURRENT_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
  FAKE_LOG="$CURRENT_LOG" \
  FAKE_BREW_STATE="$CURRENT_STATE" \
  FAKE_BREW_PREFIX="$CURRENT_PREFIX" \
  bash "$ROOT_DIR/install.sh" "$@" > "$output" 2>&1
}

new_environment full
mkdir -p "$CURRENT_HOME/.config/nvim"
printf 'legacy config\n' > "$CURRENT_HOME/.config/nvim/init.lua"
ln -s "$CURRENT_ROOT/missing-git-config" "$CURRENT_HOME/.config/git"
run_install "$CURRENT_ROOT/first-output"

assert_symlink "$CURRENT_HOME/.config/nvim"
assert_symlink "$CURRENT_HOME/.config/git"
assert_symlink "$CURRENT_HOME/.config/herdr"
assert_symlink "$CURRENT_HOME/.zshenv"
assert_directory "$CURRENT_HOME/.cache/zsh"
assert_directory "$CURRENT_HOME/.local/state/zsh"
assert_directory "$CURRENT_HOME/.config/tmux/plugins/tpm"
assert_contains "$CURRENT_LOG" 'ya pkg install'
assert_contains "$CURRENT_LOG" 'brew link ffmpeg-full'
assert_contains "$CURRENT_LOG" 'brew link imagemagick-full'

backup="$(find "$CURRENT_HOME/.dotfiles-backup" -mindepth 1 -maxdepth 1 -type d)"
assert_file "$backup/nvim/init.lua"
assert_symlink "$backup/git"
backup_count="$(find "$CURRENT_HOME/.dotfiles-backup" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
brew_install_count="$(grep -c '^brew install' "$CURRENT_LOG")"
run_install "$CURRENT_ROOT/second-output"
[[ "$backup_count" == "$(find "$CURRENT_HOME/.dotfiles-backup" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" ]] || fail 'rerun created another backup'
[[ "$brew_install_count" == "$(grep -c '^brew install' "$CURRENT_LOG")" ]] || fail 'rerun installed an already-present package'
assert_contains "$CURRENT_ROOT/second-output" 'TPM already present'
assert_contains "$CURRENT_ROOT/second-output" 'already linked'
assert_contains "$CURRENT_ROOT/first-output" 'no terminal to draw a checklist on'

new_environment selection
mkdir -p "$CURRENT_HOME/.config/nvim"
printf 'legacy config\n' > "$CURRENT_HOME/.config/nvim/init.lua"
run_install "$CURRENT_ROOT/output" --select tmux,git

assert_symlink "$CURRENT_HOME/.config/tmux"
assert_symlink "$CURRENT_HOME/.config/git"
assert_directory "$CURRENT_HOME/.config/tmux/plugins/tpm"
# A deselected package keeps its own config and never reaches stow.
assert_file "$CURRENT_HOME/.config/nvim/init.lua"
assert_absent "$CURRENT_HOME/.config/zsh"
assert_absent "$CURRENT_HOME/.config/yazi"
assert_absent "$CURRENT_HOME/.zshenv"
assert_absent "$CURRENT_HOME/.dotfiles-backup"
assert_lacks "$CURRENT_LOG" 'ya pkg install'
# Core formulae plus only what tmux and git pull in.
assert_contains "$CURRENT_LOG" 'stow'
assert_contains "$CURRENT_LOG" 'git-delta'
assert_lacks "$CURRENT_LOG" 'ripgrep'
assert_lacks "$CURRENT_LOG" 'herdr'
assert_lacks "$CURRENT_LOG" 'neovim'
assert_lacks "$CURRENT_LOG" 'cask'
assert_lacks "$CURRENT_LOG" 'brew link'
# Only the follow-up its selection earned.
assert_contains "$CURRENT_ROOT/output" 'prefix + I'
assert_lacks "$CURRENT_ROOT/output" 'exec zsh'
assert_lacks "$CURRENT_ROOT/output" 'Nerd Font'

new_environment rejects-unknown-item
if run_install "$CURRENT_ROOT/output" --select nvim,typo; then
  fail 'an unknown item name was accepted'
fi
assert_contains "$CURRENT_ROOT/output" "unknown item 'typo'"
assert_absent "$CURRENT_HOME/.config/nvim"

new_environment lists-items
run_install "$CURRENT_ROOT/output" --list
assert_contains "$CURRENT_ROOT/output" 'wezterm'
assert_contains "$CURRENT_ROOT/output" 'yazi-previews'
assert_lacks "$CURRENT_LOG" 'stow'

new_environment protected-zshenv
printf 'export MACHINE_ONLY=1\n' > "$CURRENT_HOME/.zshenv"
DOTFILES_SKIP_BREW=1 \
DOTFILES_ALL=1 \
HOME="$CURRENT_HOME" \
PATH="$CURRENT_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
FAKE_LOG="$CURRENT_LOG" \
FAKE_BREW_STATE="$CURRENT_STATE" \
FAKE_BREW_PREFIX="$CURRENT_PREFIX" \
bash "$ROOT_DIR/install.sh" > "$CURRENT_ROOT/output" 2>&1
assert_file "$CURRENT_HOME/.zshenv"
assert_contains "$CURRENT_ROOT/output" 'is a real file, not a symlink — leaving it alone'

printf 'install tests passed\n'
