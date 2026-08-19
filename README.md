# dotfiles

A macOS terminal environment built around **zsh + tmux + WezTerm + Starship**, themed with Catppuccin Mocha. Configuration is XDG-compliant (nothing is dumped in `$HOME` except the one `~/.zshenv` symlink zsh insists on) and installed with [GNU Stow](https://www.gnu.org/software/stow/).

Each configuration directory listed below is a Stow *package* whose contents mirror `$HOME`:

<!-- catalog:packages:start -->
| Package | Stow target | Contents |
| --- | --- | --- |
| `atuin/` | `~/.config/atuin/` | shell history config, Catppuccin Mocha themes |
| `eza/` | `~/.config/eza/` | `ls` replacement colour theme |
| `git/` | `~/.config/git/` | `config` (diff/merge defaults, delta pager — no identity), global `ignore` |
| `lazygit/` | `~/.config/lazygit/` | git UI theme (Catppuccin Mocha), delta diff renderer |
| `nvim/` | `~/.config/nvim/` | LazyVim-based editor config, `lazy-lock.json`, lazy.nvim-managed plugins |
| `starship/` | `~/.config/starship/` | prompt theme, custom git-remote and worktree modules |
| `tmux/` | `~/.config/tmux/` | `tmux.conf`, `bin/tmux-sessionizer.sh`, TPM-managed plugins |
| `wezterm/` | `~/.config/wezterm/` | terminal config, key tables, status line |
| `yazi/` | `~/.config/yazi/` | file manager theme, `ya pkg`-managed flavors |
| `zsh/` | `~/.config/zsh/` | shell config split into `.zshenv`, `.zprofile`, `.zshrc`, aliases, fzf, plugins, and prompt |
<!-- catalog:packages:end -->

`.automation/` contains repository-maintenance tools and is never passed to Stow.

---

## Requirements

- **macOS on Apple Silicon.** `zsh/.config/zsh/.zprofile` hardcodes `eval "$(/opt/homebrew/bin/brew shellenv)"`. On Intel macOS change that path to `/usr/local/bin/brew`.
- **[Homebrew](https://brew.sh)** — everything else is installed through it.
- **GNU Stow** — the only hard prerequisite for the install itself.

WezTerm is not required; the zsh and tmux configs work in any terminal that supports true colour.

---

## Package installation

`install.sh` installs all of the following. The lists are reproduced here so you can install selectively or audit what each dependency is for.

### Required

<!-- catalog:required-formulae:start -->
```sh
brew install stow zsh tmux starship eza bat fd fzf ripgrep zoxide sesh yazi neovim git git-delta lazygit atuin
```

| Package | Why it is needed |
| --- | --- |
| `stow` | installs this repo into `$HOME` |
| `zsh` | the shell itself |
| `tmux` | terminal multiplexer |
| `starship` | the prompt (`prompt.zsh`) |
| `eza` | `ls` / `ll` / `la` / `tree` aliases |
| `bat` | `cat` alias, `$MANPAGER`, fzf preview |
| `fd` | `$FZF_DEFAULT_COMMAND`, the tmux sessionizer |
| `fzf` | `Ctrl-T` / `Alt-C`, sesh pickers |
| `ripgrep` | `grep` alias |
| `zoxide` | smart `cd` (`.zshrc`) |
| `sesh` | session picker — `Esc-s` in zsh, `prefix K` in tmux |
| `yazi` | the `y` function and `prefix C-y` popup; `ya pkg` installs its flavors |
| `neovim` | `$EDITOR` / `$VISUAL`, `vim` alias, tmux config-edit menu |
| `git` | version control |
| `git-delta` | `core.pager` / `interactive.diffFilter` |
| `lazygit` | the `lg` alias (`aliases.zsh`) |
| `atuin` | `Ctrl-R` history search (`.zshrc`) |
<!-- catalog:required-formulae:end -->

### Yazi preview backends

Full installation includes preview support for media, PDFs, SVGs and archives inside yazi:

<!-- catalog:yazi-preview-formulae:start -->
```sh
brew install ffmpeg-full imagemagick-full poppler resvg sevenzip jq
brew link ffmpeg-full imagemagick-full --force --overwrite
```
<!-- catalog:yazi-preview-formulae:end -->

The link command is required. `ffmpeg-full` and `imagemagick-full` are `:versioned_formula`, so Homebrew installs them **keg-only** and never links them into `/opt/homebrew/bin`. Without the force-link, `ffmpeg`, `ffprobe` and `magick` are absent from `$PATH` and yazi's video and image previews fail silently. `--overwrite` replaces any conflicting symlinks left by a plain `ffmpeg` or `imagemagick` install.

### Nerd Fonts

The prompt, tmux status line and eza icons all use Nerd Font glyphs:

<!-- catalog:font-casks:start -->
```sh
brew install --cask font-maple-mono-nf-cn font-proggy-clean-tt-nerd-font font-fantasque-sans-mono-nerd-font font-symbols-only-nerd-font
```
<!-- catalog:font-casks:end -->

`wezterm.lua` requests them in that order as a fallback chain: `Maple Mono NF CN` → `ProggyClean Nerd Font` → `FantasqueSansM Nerd Font`.

### Installed outside Homebrew

These are all sourced defensively, so their absence is not fatal:

| Tool | Where the config expects it |
| --- | --- |
| WezTerm | the terminal itself |
| `nvm` | `$XDG_CONFIG_HOME/nvm` (`.zprofile`) |
| `bun` | `$HOME/.bun` (`.zprofile`) |
| OrbStack | `~/.orbstack/shell/init.zsh` (`.zprofile`) |
| `claude` CLI | the `gac` commit-message helper (`aliases.zsh`) |

### A note on the zsh plugin formulae

`zsh-autosuggestions`, `zsh-syntax-highlighting` and `zsh-autocomplete` are **not** used even if Homebrew has them installed — `plugins.zsh` clones its own copies into `$ZDOTDIR/plugins`. The Homebrew versions are safe to `brew uninstall`.

---

## Installation

```sh
git clone <this-repo> ~/dotfiles
cd ~/dotfiles
./install.sh
```

`install.sh` is idempotent — re-running it on a configured machine is a no-op. Set `DOTFILES_SKIP_BREW=1` to re-stow without touching Homebrew.

**Your existing config is not destroyed.** Before stowing, `install.sh` checks every `~/.config/<package>` path it is about to claim. Anything real already sitting there — a hand-written `~/.config/nvim`, a symlink pointing somewhere else, even a broken one — is moved to `~/.dotfiles-backup/<timestamp>/<package>/` and the path is reported on stdout. Links this repo already owns are recognised and left alone, so a re-run never manufactures a backup of itself.

`~/.gitconfig` is left alone on purpose. Git reads it *after* `~/.config/git/config`, which makes the two a layer pair: this repo's `git/` package carries the settings that are the same everywhere, and `~/.gitconfig` stays untracked for whatever belongs to that one machine — `user.name` / `user.email` above all, plus any work-only `includeIf`, signing key or credential helper. Nothing machine-specific goes in the repo, and nothing in the repo needs editing per machine.

### Machine-local state

<!-- catalog:machine-local-state:start -->
- **`~/.gitconfig`** — Git identity, credential helpers, signing keys, and machine-specific includes remain untracked.
- **`~/.config/zsh/secrets.zsh`** — API keys and tokens remain gitignored machine-local state.
- **`~/.zshenv`** — A real file is preserved rather than overwritten because it can contain machine-specific settings.
<!-- catalog:machine-local-state:end -->

Then:

<!-- catalog:followups:start -->
1. Start a new shell (`exec zsh`). The zsh plugins clone themselves on first run.
2. Inside tmux, press `prefix + I` (`C-s` then `Shift-i`) to install the tmux plugins.
3. Set your terminal font to `Maple Mono NF CN` (or another installed Nerd Font).
<!-- catalog:followups:end -->

### Manual equivalent

Everything `install.sh` does, by hand:

<!-- catalog:manual-equivalent:start -->
```sh
cd ~/dotfiles

# 0. Move any pre-existing config out of the way — stow will not overwrite it.
mkdir -p ~/.dotfiles-backup/manual
for pkg in atuin eza git lazygit nvim starship tmux wezterm yazi zsh; do
  # -e is false for a broken symlink, hence the second test.
  if [ -e ~/.config/"$pkg" ] || [ -L ~/.config/"$pkg" ]; then
    mv ~/.config/"$pkg" ~/.dotfiles-backup/manual/"$pkg"
  fi
done

# 1. Symlink the packages into $HOME.
stow --restow --target="$HOME" atuin eza git lazygit nvim starship tmux wezterm yazi zsh

# 2. Bootstrap ~/.zshenv. Stow will NOT do this — see below.
ln -sfn "$HOME/.config/zsh/.zshenv" "$HOME/.zshenv"

# 3. Create the cache/state directories the configs write into.
mkdir -p ~/.cache/zsh ~/.local/state/zsh ~/.local/bin

# 4. Install the tmux plugin manager.
git clone --depth=1 https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm

# 5. Fetch the yazi flavors pinned in yazi/.config/yazi/package.toml.
ya pkg install
```
<!-- catalog:manual-equivalent:end -->

**Why step 2 exists.** zsh only ever auto-reads `~/.zshenv`, and that file is precisely what sets `ZDOTDIR` to `~/.config/zsh`. Without the symlink, nothing under `~/.config/zsh` is ever loaded. Stow cannot create it, because the link crosses out of the package tree.

**Why step 3 matters.** `.zshrc` runs `compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"` and sets `HISTFILE="$XDG_STATE_HOME/zsh/history"`. Neither creates its parent directory, so completion caching and history silently fail if they are missing.

After a successful install, `~/.config` holds folded directory symlinks pointing back into the repo:

```
~/.config/atuin    -> ../dotfiles/atuin/.config/atuin
~/.config/eza      -> ../dotfiles/eza/.config/eza
~/.config/git      -> ../dotfiles/git/.config/git
~/.config/lazygit  -> ../dotfiles/lazygit/.config/lazygit
~/.config/nvim     -> ../dotfiles/nvim/.config/nvim
~/.config/starship -> ../dotfiles/starship/.config/starship
~/.config/tmux     -> ../dotfiles/tmux/.config/tmux
~/.config/wezterm  -> ../dotfiles/wezterm/.config/wezterm
~/.config/yazi     -> ../dotfiles/yazi/.config/yazi
~/.config/zsh      -> ../dotfiles/zsh/.config/zsh
~/.zshenv          -> /Users/<you>/.config/zsh/.zshenv
```

---

## Paths and environment

### Load order

```
~/.zshenv  (symlink)
  └─ $ZDOTDIR/.zshenv     XDG bases, ZDOTDIR, editor, pager, PATH
       ├─ .zprofile        brew shellenv, OrbStack, bun, nvm      (login shells)
       └─ .zshrc           history, options, zoxide, completion   (interactive shells)
            ├─ fzf.zsh
            ├─ aliases.zsh
            ├─ plugins.zsh
            ├─ prompt.zsh
            └─ secrets.zsh      API keys — gitignored, sourced only if present
```

### Environment variables

| Variable | Value | Set in |
| --- | --- | --- |
| `XDG_CONFIG_HOME` | `~/.config` | `.zshenv` |
| `XDG_CACHE_HOME` | `~/.cache` | `.zshenv` |
| `XDG_DATA_HOME` | `~/.local/share` | `.zshenv` |
| `XDG_STATE_HOME` | `~/.local/state` | `.zshenv` |
| `ZDOTDIR` | `$XDG_CONFIG_HOME/zsh` | `.zshenv` |
| `EDITOR`, `VISUAL` | `nvim` | `.zshenv` |
| `MANPAGER` | `bat -l man -p` (falls back to `batcat`) | `.zshenv` |
| `NVM_DIR` | `$XDG_CONFIG_HOME/nvm` | `.zshenv` |
| `STARSHIP_CONFIG` | `$XDG_CONFIG_HOME/starship/starship.toml` | `.zshenv` |
| `EZA_CONFIG_DIR` | `~/.config/eza` | `.zshenv` |
| `PATH` | prepends `~/.local/bin` | `.zshenv` |
| `BUN_INSTALL` | `~/.bun` (also prepends `$BUN_INSTALL/bin`) | `.zprofile` |
| `HISTFILE` | `$XDG_STATE_HOME/zsh/history` (100k entries, shared) | `.zshrc` |
| `FZF_DEFAULT_COMMAND` | `fd --hidden --strip-cwd-prefix --exclude .git` | `fzf.zsh` |
| `FZF_CTRL_T_*`, `FZF_ALT_C_*` | `bat` / `eza` previews | `fzf.zsh` |
| `FZF_TMUX_OPTS` | `-p90%,70%` | `fzf.zsh` |
| `TMUX_PLUGIN_MANAGER_PATH` | `~/.config/tmux/plugins` | `tmux.conf` |

Completion functions are loaded from `~/.config/zsh/completions` (currently `_sesh`), and the
completion cache lives at `$XDG_CACHE_HOME/zsh/zcompdump`.

### Secrets

API keys and tokens go in `~/.config/zsh/secrets.zsh`, sourced last by `.zshrc`. That file is
gitignored, so it never reaches the remote; `secrets.zsh.example` is the tracked template and must
stay free of real values.

Setting one up on a new machine:

```bash
cp "$ZDOTDIR/secrets.zsh.example" "$ZDOTDIR/secrets.zsh"
chmod 600 "$ZDOTDIR/secrets.zsh"
$EDITOR "$ZDOTDIR/secrets.zsh"          # fill in the real values
```

`.zshrc` sources it only when the file is readable, so a fresh clone with no `secrets.zsh` still
starts a working shell.

Two things worth knowing:

- **`~/.config/zsh` is a symlink into this repo.** Anything created under it is a file inside the
  working tree, which is exactly why `.gitignore` — not the file's location — is what keeps the key
  out of a commit. The ignore rules cover `**/secrets.zsh`, `**/*.secret.zsh`, `*.env`, `.env*`,
  `**/*.key`, and `**/*.pem`.
- **`git add -f` bypasses `.gitignore`.** Before committing, `git status --short` should never list
  `secrets.zsh`. If it ever does, the ignore rule stopped matching — fix that before you commit.

---

## Keybinds and commands

zsh runs in **vi mode** (`set -o vi`).

### zsh

| Key | Action |
| --- | --- |
| `Ctrl-E` | accept the autosuggestion |
| `Alt-s` | sesh session picker |
| `Ctrl-T` | fzf file picker with `bat` preview |
| `Alt-C` | fzf directory picker with `eza` tree preview |
| `Ctrl-R` | atuin history search — rebound after fzf's own `Ctrl-R` |

### tmux — prefix is `Ctrl-s`

| Key | Action |
| --- | --- |
| `\` / `-` | split horizontally / vertically, keeping cwd |
| `h` `j` `k` `l` | resize pane by 5 |
| `z` | zoom pane |
| `v` | enter copy mode (vi keys, `v` select, `y` copy) |
| `r` | reload `tmux.conf` |
| `K` | sesh picker in an fzf-tmux popup |
| `f` | project sessionizer (`fd` over `~/Documents/github`, 2 levels deep) |
| `n` | new session, prompting for a name |
| `o` | tmux-sessionx |
| `Ctrl-y` | yazi in a floating popup |
| `Ctrl-t` | floating zsh shell |
| `d` | config-edit menu (`.zshrc` / `.zprofile` / `tmux.conf`) |

Sessions are persisted by tmux-resurrect and auto-saved every 15 minutes by tmux-continuum.

### WezTerm — leader is `Ctrl-a`

| Key | Action |
| --- | --- |
| `Leader r` | enter the `resize_pane` key table (stays active) |
| `Leader .` | enter the `move_tab` key table (stays active) |

The active key table is shown in the status line alongside the workspace, cwd and foreground command. Colour scheme is `nordfox`; font size 12.5 at 120 fps, 0.9 opacity with macOS blur.

### Custom shell commands

| Command | What it does |
| --- | --- |
| `gac` | pipes `git diff --cached` through the `claude` CLI to draft a conventional-commit message, shows it, and commits after confirmation |
| `y` | opens yazi and `cd`s to wherever you left it |
| `zr` | re-source `.zshrc` |
| `zplugin-update` | `git pull --ff-only` every zsh plugin |
| `ta` | `tmux a` |
| `ls` `ll` `la` `tree` | `eza` with icons and git status |
| `cat` `grep` `vim` | `bat`, `rg --color=auto`, `nvim` |

A `chpwd` hook auto-activates `./venv` or `./.venv` when you enter a Python project and deactivates it when you leave.

---

## Updating

```sh
brew upgrade                                    # tools
zplugin-update                                  # zsh plugins
ya pkg upgrade                                  # yazi flavors (updates package.toml)
# inside tmux: prefix + U                        # tmux plugins
cd ~/dotfiles && stow -R -t "$HOME" zsh tmux    # re-apply after adding new files to a package
.automation/render-readme.sh                     # regenerate catalog-derived README sections
.automation/render-readme.sh --check             # verify README has no catalog drift
```

Plugin directories (`zsh/.config/zsh/plugins/`, `tmux/.config/tmux/plugins/`, `yazi/.config/yazi/flavors/`) are gitignored — they are manager-owned clones, not source. A fresh clone of this repo will not contain them; the zsh ones reappear on the next shell start and TPM and the yazi flavors are re-fetched by `install.sh`.

---

## Uninstall

```sh
cd ~/dotfiles
stow -D -t "$HOME" atuin eza git lazygit nvim starship tmux wezterm yazi zsh
rm ~/.zshenv
```

Cache, state and plugin directories under `~/.cache`, `~/.local/state` and `~/.config/*/plugins` are left behind; remove them by hand if you want a clean slate.

---

## Troubleshooting

**`stow` reports a conflict.** `install.sh` clears `~/.config/<package>` collisions on its own, so a surviving conflict is a path outside that pattern. Move it aside and re-run. `install.sh` deliberately does not use `--adopt`, which would overwrite the repo's contents with whatever is in `$HOME`.

**Getting your old config back.** Look in `~/.dotfiles-backup/`, newest timestamp last. Nothing is ever deleted from there, so it grows one directory per install that found something to rescue — prune it by hand when you no longer need it.

**`~/.zshenv` was left alone.** The backup pass only covers `~/.config`. If `~/.zshenv` is a real file rather than a symlink, `install.sh` warns and skips it instead of moving it, because that file often holds machine-specific settings. Back it up yourself, delete it, and re-run.

**Prompt shows boxes instead of icons.** The terminal font is not a Nerd Font. Install the casks above and select one.

**`prefix f` does nothing.** `bin/tmux-sessionizer.sh` is not marked executable; it works because tmux invokes it as `tmux neww <path>` and the shebang is honoured. If you want to call it directly, `chmod +x` it. It also expects projects under `~/Documents/github` — edit the `fd` path in the script to match your layout. The script accepts a directory as its single argument, and sources a `.tmux-sessionizer` file from the project (or `$HOME`) into the new session if one exists.

**Completion or history not persisting.** `~/.cache/zsh` or `~/.local/state/zsh` is missing; see step 3 of the manual install.
