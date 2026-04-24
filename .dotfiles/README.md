# dotfiles

Personal dotfiles for a new machine setup, managed as a bare git repo.

## Managing dotfiles

Once set up, use `dit` to interact with the dotfiles repo — it's an alias for `git` scoped to the bare repo and home directory worktree. For example:

```sh
dit status
dit add .gitconfig
dit commit -m "update gitconfig"
dit push
```

`dit` is defined in your shell config as:

```sh
alias dit='git --git-dir="$HOME/.dotfiles.git" --work-tree="$HOME"'
```

## Bootstrap

To set up a new machine, run:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/naydichev/dotfiles/main/.dotfiles/scripts/init_os.sh)"
```

This runs in **dry-run mode by default** — it will print what it would do without making any changes. To actually run it:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/naydichev/dotfiles/main/.dotfiles/scripts/init_os.sh)" -- --run
```

## What it does

- Clones this repo as a bare repo into `~/.dotfiles.git` (or pulls latest if already present)
- Installs [oh-my-zsh](https://ohmyz.sh/)
- Initializes submodules ([powerlevel10k](https://github.com/romkatv/powerlevel10k), zsh-autosuggestions, zsh-syntax-highlighting)
- Sets zsh as the default shell
- Installs homebrew, casks, and formulae (macOS only)
- Creates `~/.ssh` with correct permissions (macOS only)
- Symlinks macOS/1Password-specific configs (macOS only)
- Optionally sets up [LazyVim](https://www.lazyvim.org/)

## Directory structure

Platform-specific configs live in `.dotfiles/` and are symlinked to their expected locations by the init script:

```
~/.dotfiles/
├── git/
│   └── config-darwin-1password   # -> ~/.gitconfig-darwin-1password (macOS)
├── ssh/
│   └── config-darwin-1password   # -> ~/.ssh/config-darwin-1password (macOS)
├── zsh/
│   ├── aliases.zsh
│   ├── exports.zsh
│   ├── plugins/
│   └── themes/
└── scripts/
    └── init_os.sh
```

The main config files (`.gitconfig`, `.ssh/config`) include from these symlinked paths. On non-macOS systems, the symlinks don't exist and the includes are silently skipped.

Files ending in `-local` (e.g., `.gitconfig-local`, `.ssh/config-local`) are host-specific and not tracked. The init script prompts for `.gitconfig-local` values; others should be created manually as needed.

## Manual setup

If you've already cloned the repo and just want to run the script locally:

```sh
~/.dotfiles/scripts/init_os.sh          # dry-run
~/.dotfiles/scripts/init_os.sh --run    # apply
```

## Prerequisites

- Bash 4.0+
- `git`, `curl`, and `zsh`

## Manual steps after running the script

**1Password setup**
- Sign in to 1Password (installed by the script)
- Go to Settings → Developer → enable the SSH agent
- Go to Settings → Developer → enable Git Commit Signing
- Add your SSH key to your GitHub account if not already there

The 1Password config files are already set up in `.dotfiles/git/` and `.dotfiles/ssh/` and symlinked by the init script. If your 1Password settings differ (different signing key, etc.), update the files in `.dotfiles/`.

**Verify everything works**
- Test SSH: `ssh -T git@github.com`
- Test commit signing: `git commit --allow-empty -m "test signing"` (check for "Verified" badge on GitHub)
- Verify dotfiles remote: `dit remote -v` (should show `git@github.com:...`)
