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
assert_contains() { grep -Fq "$2" "$1" || fail "expected '$2' in $1"; }

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

run_install() {
  local output="$1"
  HOME="$CURRENT_HOME" \
  PATH="$CURRENT_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
  FAKE_LOG="$CURRENT_LOG" \
  FAKE_BREW_STATE="$CURRENT_STATE" \
  FAKE_BREW_PREFIX="$CURRENT_PREFIX" \
  bash "$ROOT_DIR/install.sh" > "$output" 2>&1
}

new_environment full
mkdir -p "$CURRENT_HOME/.config/nvim"
printf 'legacy config\n' > "$CURRENT_HOME/.config/nvim/init.lua"
ln -s "$CURRENT_ROOT/missing-git-config" "$CURRENT_HOME/.config/git"
run_install "$CURRENT_ROOT/first-output"

assert_symlink "$CURRENT_HOME/.config/nvim"
assert_symlink "$CURRENT_HOME/.config/git"
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

new_environment protected-zshenv
printf 'export MACHINE_ONLY=1\n' > "$CURRENT_HOME/.zshenv"
DOTFILES_SKIP_BREW=1 \
HOME="$CURRENT_HOME" \
PATH="$CURRENT_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
FAKE_LOG="$CURRENT_LOG" \
FAKE_BREW_STATE="$CURRENT_STATE" \
FAKE_BREW_PREFIX="$CURRENT_PREFIX" \
bash "$ROOT_DIR/install.sh" > "$CURRENT_ROOT/output" 2>&1
assert_file "$CURRENT_HOME/.zshenv"
assert_contains "$CURRENT_ROOT/output" 'is a real file, not a symlink — leaving it alone'

printf 'install tests passed\n'
