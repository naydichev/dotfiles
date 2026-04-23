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
sh -c "$(curl -fsSL https://raw.githubusercontent.com/naydichev/dotfiles/main/.dotfiles/scripts/init_os.sh)"
```

This runs in **dry-run mode by default** — it will print what it would do without making any changes. To actually run it:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/naydichev/dotfiles/main/.dotfiles/scripts/init_os.sh)" -- --run
```

## What it does

- Clones this repo as a bare repo into `~/.dotfiles.git`
- Installs [oh-my-zsh](https://ohmyz.sh/)
- Installs [powerlevel10k](https://github.com/romkatv/powerlevel10k) theme
- Installs zsh plugins (zsh-autosuggestions, zsh-syntax-highlighting)
- Sets zsh as the default shell
- Installs homebrew and a set of casks (macOS only)
- Optionally sets up [LazyVim](https://www.lazyvim.org/)

## Manual setup

If you've already cloned the repo and just want to run the script locally:

```sh
~/.dotfiles/scripts/init_os.sh          # dry-run
~/.dotfiles/scripts/init_os.sh --run    # apply
```

## Prerequisites

- git and curl must be available
- SSH key must be set up for GitHub (for the bare repo clone)

## Manual steps after running the script

These can't be automated and need to be done by hand:

**1Password**
- Install and sign in to 1Password
- Go to Settings → Developer → enable the SSH agent
- Go to Settings → Developer → enable commit signing
- Add your SSH key to your GitHub account if not already there

**Git commit signing**
- Open 1Password → Settings → Developer → Git Commit Signing
- Click "Copy Config" to copy the signing config to your clipboard
- Run: `pbpaste > ~/.gitconfig-darwin`
- Verify signing works: `git commit --allow-empty -m "test signing"`
- Check the commit on GitHub shows a "Verified" badge

**Powerlevel10k**
- Run `p10k configure` to set up your prompt

**Dotfiles remote**
- After 1Password SSH agent is running, verify the remote was switched: `dit remote -v`
- Test a push to confirm SSH auth is working
