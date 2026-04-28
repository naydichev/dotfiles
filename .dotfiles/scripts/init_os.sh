#!/usr/bin/env bash

set -euo pipefail

## -- BASH VERSION CHECK -- ##

if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
	echo "Error: This script requires Bash 4.0+ (found ${BASH_VERSION})"
	exit 1
fi

## -- DEPENDENCY CHECK -- ##

REQUIRED_CMDS=(git curl zsh)
MISSING_CMDS=()

for cmd in "${REQUIRED_CMDS[@]}"; do
	if ! command -v "$cmd" &>/dev/null; then
		MISSING_CMDS+=("$cmd")
	fi
done

if [[ ${#MISSING_CMDS[@]} -gt 0 ]]; then
	echo "Error: Required commands not found: ${MISSING_CMDS[*]}"
	exit 1
fi

## -- COLORS -- ##

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

## -- LOGGING -- ##

info() { echo -e "${BLUE}==>${RESET} ${BOLD}$*${RESET}"; }
success() { echo -e "${GREEN} ✓${RESET} $*"; }
warning() { echo -e "${YELLOW} !${RESET} $*"; }
error() { echo -e "${RED} ✗${RESET} $*" >&2; }

## -- SUMMARY TRACKING -- ##

SUMMARY_INSTALLED=()
SUMMARY_FOUND=()
SUMMARY_SKIPPED=()
SUMMARY_WARNINGS=()

## -- DRYRUN -- ##

DRYRUN=true

for arg in "$@"; do
	[[ "$arg" == "--run" ]] && DRYRUN=false
done

if $DRYRUN; then
	warning "Running in DRYRUN mode, use --run to actually run the script"
fi

## -- HELPER FUNCTIONS -- ##

function exists() {
	command -v "$1" &>/dev/null
}

function dit() {
	git --git-dir="$DOTFILES_GIT" --work-tree="$HOME" "$@"
}

function backup_if_exists() {
	local path=$1
	if [[ -e "$path" ]]; then
		warning "Backing up ${path} to ${path}.bak"
		dryrun_safe_exec mv "${path}"{,.bak}
	fi
}

function dryrun_safe_exec() {
	if $DRYRUN; then
		echo -e "  ${YELLOW}[DRYRUN]${RESET} $*"
	else
		"$@"
	fi
}

function confirm() {
	local prompt=$1
	local default=${2:-n}
	local hint="[y/N]"
	[[ "$default" == "y" ]] && hint="[Y/n]"

	if $DRYRUN; then
		echo -e "  ${YELLOW}[DRYRUN]${RESET} Would prompt: $prompt $hint (defaulting to $default)"
		[[ "$default" == "y" ]]
		return
	fi

	read -r -p "$prompt $hint " response
	response="${response:-$default}"
	[[ "${response,,}" == "y" ]]
}

## -- PATH VARIABLES -- ##

DOTFILES_REPO="${DOTFILES_REPO:-naydichev/dotfiles}"
DOTFILES_REPO_SSH="git@github.com:${DOTFILES_REPO}.git"
DOTFILES_REPO_HTTPS="https://github.com/${DOTFILES_REPO}.git"

DOTFILES_HOME="$HOME/.dotfiles"
DOTFILES_GIT="$HOME/.dotfiles.git"

OH_MY_ZSH_HOME="$HOME/.oh-my-zsh"
OH_MY_ZSH_INSTALL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

NVIM_CONFIG="$HOME/.config/nvim"
NVIM_DATA="$HOME/.local/share/nvim"
NVIM_STATE="$HOME/.local/state/nvim"
NVIM_CACHE="$HOME/.cache/nvim"
LAZYVIM_REPO="https://github.com/LazyVim/starter"

SSH_DIR="$HOME/.ssh"

GITCONFIG_LOCAL="$HOME/.gitconfig-local"

GIT_DARWIN_1PASSWORD_SOURCE="$DOTFILES_HOME/git/config-darwin-1password"
GIT_DARWIN_1PASSWORD_TARGET="$HOME/.gitconfig-darwin-1password"

SSH_DARWIN_1PASSWORD_SOURCE="$DOTFILES_HOME/ssh/config-darwin-1password"
SSH_DARWIN_1PASSWORD_TARGET="$HOME/.ssh/config-darwin-1password"

## -- SCRIPT BEGIN -- ##

echo -e "\n${BOLD}Let's get this computer setup!${RESET}\n"

## Dotfiles

info "Checking for dotfiles..."

if [[ ! -e "$DOTFILES_GIT" ]]; then
	warning "dotfiles not found, cloning..."
	dryrun_safe_exec git clone --bare --recurse-submodules "$DOTFILES_REPO_HTTPS" "$DOTFILES_GIT"
	dryrun_safe_exec dit checkout
	dryrun_safe_exec dit config status.showUntrackedFiles no
	SUMMARY_INSTALLED+=("dotfiles")

	## Switch dotfiles remote to SSH (will work once 1Password is set up)
	info "Switching dotfiles remote to SSH..."
	dryrun_safe_exec dit remote set-url origin "$DOTFILES_REPO_SSH"
else
	success "dotfiles found"
	info "Pulling latest changes..."
	if ! dryrun_safe_exec dit pull --rebase --autostash; then
		warning "Failed to pull dotfiles (may have conflicts or be offline)"
		if ! confirm "Continue anyway?"; then
			error "Aborting. Please resolve conflicts manually and re-run."
			exit 1
		fi
	fi
	info "Updating submodules..."
	dryrun_safe_exec dit submodule update --init --recursive
	SUMMARY_FOUND+=("dotfiles")
fi

## Oh My Zsh

info "Checking for oh-my-zsh..."

if [[ ! -e "$OH_MY_ZSH_HOME" ]]; then
	warning "oh-my-zsh not found, installing..."
	export RUNZSH=no
	dryrun_safe_exec sh -c "$(curl -fsSL "$OH_MY_ZSH_INSTALL")"
	unset RUNZSH
	SUMMARY_INSTALLED+=("oh-my-zsh")
else
	success "oh-my-zsh found"
	SUMMARY_FOUND+=("oh-my-zsh")
fi

## ZSH Plugins + Powerlevel10k (via submodules)

info "Initializing dotfile submodules (powerlevel10k, zsh-autosuggestions, zsh-syntax-highlighting)..."

if [[ ! -e "$DOTFILES_HOME/zsh/themes/powerlevel10k/README.md" ]]; then
	dryrun_safe_exec dit submodule update --init --recursive
	SUMMARY_INSTALLED+=("zsh submodules")
else
	success "submodules already initialized"
	SUMMARY_FOUND+=("zsh submodules")
fi

## Default shell

info "Checking default shell..."

if [[ "$(basename "$SHELL")" != "zsh" ]]; then
	error "Default shell is not zsh (found: $SHELL)"
	error "Please change your default shell to zsh manually: chsh -s \$(command -v zsh)"
	SUMMARY_WARNINGS+=("Default shell is not zsh")
else
	success "zsh is the default shell"
	SUMMARY_FOUND+=("zsh as default shell")
fi

## Homebrew + Casks (macOS only)

OS=$(uname)

if [[ "$OS" != "Darwin" ]]; then
	warning "Not a mac, skipping macOS setup"
	SUMMARY_SKIPPED+=("homebrew" "homebrew casks" "homebrew formulae" "macOS config symlinks" "macOS defaults")
else
	info "Checking for homebrew..."

	if ! exists brew; then
		warning "homebrew not found, installing..."
		dryrun_safe_exec /bin/bash -c '$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)'
		SUMMARY_INSTALLED+=("homebrew")
	else
		success "homebrew found"
		SUMMARY_FOUND+=("homebrew")
	fi

	CASKS=(
		1password
		busycal
		firefox
		ghostty
		qlmarkdown
		raycast
		readdle-spark
		spotify
		syntax-highlight
		telegram
		whatsapp
		zoom
	)

	CASK_LIST=$(printf "\n   - %s" "${CASKS[@]}")
	info "Going to install the following casks via homebrew:${CASK_LIST}"

	if confirm "Ready to install casks?"; then
		dryrun_safe_exec brew install --cask "${CASKS[@]}"
		info "Resetting QuickLook server..."
		dryrun_safe_exec qlmanage -r
		SUMMARY_INSTALLED+=("homebrew casks")
	else
		SUMMARY_SKIPPED+=("homebrew casks")
	fi

	## macOS-specific config symlinks (1Password integration)
	info "Setting up macOS-specific config symlinks..."

	# Ensure ~/.ssh exists with correct permissions
	if [[ ! -d "$SSH_DIR" ]]; then
		dryrun_safe_exec mkdir -p "$SSH_DIR"
		dryrun_safe_exec chmod 700 "$SSH_DIR"
	fi

	declare -A SYMLINKS=(
		["$GIT_DARWIN_1PASSWORD_TARGET"]="$GIT_DARWIN_1PASSWORD_SOURCE"
		["$SSH_DARWIN_1PASSWORD_TARGET"]="$SSH_DARWIN_1PASSWORD_SOURCE"
	)

	SYMLINKS_CREATED=false
	for TARGET in "${!SYMLINKS[@]}"; do
		SOURCE="${SYMLINKS[$TARGET]}"

		if [[ "$(readlink "$TARGET" 2>/dev/null)" == "$SOURCE" ]]; then
			success "$(basename "$TARGET") symlink already correct"
		else
			if [[ -e "$TARGET" || -L "$TARGET" ]]; then
				warning "Backing up existing $(basename "$TARGET")"
				dryrun_safe_exec mv "$TARGET" "${TARGET}.bak"
				SUMMARY_WARNINGS+=("Backed up $(basename "$TARGET") to $(basename "$TARGET").bak")
			fi
			dryrun_safe_exec ln -sf "$SOURCE" "$TARGET"
			success "Symlinked $(basename "$TARGET")"
			SYMLINKS_CREATED=true
		fi
	done

	if $SYMLINKS_CREATED; then
		SUMMARY_INSTALLED+=("macOS config symlinks")
	else
		SUMMARY_FOUND+=("macOS config symlinks")
	fi

	FORMULAE=(
		bat
		lsd
		jq
		neovim
		wget
	)

	FORMULAE_LIST=$(printf "\n   - %s" "${FORMULAE[@]}")
	info "Going to install the following formulae via homebrew:${FORMULAE_LIST}"

	if confirm "Ready to install formulae?"; then
		dryrun_safe_exec brew install "${FORMULAE[@]}"
		SUMMARY_INSTALLED+=("homebrew formulae")
	else
		SUMMARY_SKIPPED+=("homebrew formulae")
	fi

	## macOS defaults

	if confirm "Apply macOS system preferences?" y; then
		info "Configuring Dock..."
		dryrun_safe_exec defaults write com.apple.dock orientation -string "left"
		dryrun_safe_exec defaults write com.apple.dock autohide -bool true
		dryrun_safe_exec defaults write com.apple.dock mineffect -string "genie"
		dryrun_safe_exec defaults write com.apple.dock magnification -bool true
		dryrun_safe_exec defaults write com.apple.dock largesize -int 80
		dryrun_safe_exec killall Dock

		info "Configuring Finder..."
		dryrun_safe_exec defaults write com.apple.finder ShowPathbar -bool true
		dryrun_safe_exec defaults write com.apple.finder ShowStatusBar -bool true
		dryrun_safe_exec defaults write com.apple.finder NewWindowTarget -string "PfHm"
		dryrun_safe_exec defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"
		dryrun_safe_exec killall Finder

		SUMMARY_INSTALLED+=("macOS defaults")
	else
		SUMMARY_SKIPPED+=("macOS defaults")
	fi
fi

## LazyVim

info "Checking for LazyVim..."

if [[ -f "$NVIM_CONFIG/lua/config/lazy.lua" ]]; then
	success "LazyVim already installed"
	SUMMARY_FOUND+=("LazyVim")
elif confirm "Setup LazyVim?"; then
	info "Backing up existing neovim configs..."
	backup_if_exists "$NVIM_CONFIG"
	backup_if_exists "$NVIM_DATA"
	backup_if_exists "$NVIM_STATE"
	backup_if_exists "$NVIM_CACHE"

	info "Cloning LazyVim starter..."
	dryrun_safe_exec git clone "$LAZYVIM_REPO" "$NVIM_CONFIG"
	info "Removing LazyVim .git directory..."
	dryrun_safe_exec rm -rf "$NVIM_CONFIG/.git"
	SUMMARY_INSTALLED+=("LazyVim")
else
	SUMMARY_SKIPPED+=("LazyVim")
fi

## .gitconfig-local

info "Checking for .gitconfig-local..."

if [[ -e "$GITCONFIG_LOCAL" ]]; then
	success ".gitconfig-local found"
	SUMMARY_FOUND+=(".gitconfig-local")
else
	if $DRYRUN; then
		echo -e "  ${YELLOW}[DRYRUN]${RESET} Would prompt for git email and write $GITCONFIG_LOCAL"
		SUMMARY_SKIPPED+=(".gitconfig-local")
	else
		read -r -p "Enter your git email address: " GIT_EMAIL
		cat >"$GITCONFIG_LOCAL" <<EOF
[user]
    email = ${GIT_EMAIL}
EOF
		success "Created .gitconfig-local with email: ${GIT_EMAIL}"
		SUMMARY_INSTALLED+=(".gitconfig-local")
	fi
fi

## -- SUMMARY -- ##

echo -e "\n${BOLD}Summary${RESET}"
echo -e "───────────────────────────────"

if [[ ${#SUMMARY_INSTALLED[@]} -gt 0 ]]; then
	echo -e "${GREEN}Installed:${RESET}"
	for item in "${SUMMARY_INSTALLED[@]}"; do
		echo "  + $item"
	done
fi

if [[ ${#SUMMARY_FOUND[@]} -gt 0 ]]; then
	echo -e "${BLUE}Already present:${RESET}"
	for item in "${SUMMARY_FOUND[@]}"; do
		echo "  · $item"
	done
fi

if [[ ${#SUMMARY_SKIPPED[@]} -gt 0 ]]; then
	echo -e "${YELLOW}Skipped:${RESET}"
	for item in "${SUMMARY_SKIPPED[@]}"; do
		echo "  - $item"
	done
fi

if [[ ${#SUMMARY_WARNINGS[@]} -gt 0 ]]; then
	echo -e "${RED}Warnings:${RESET}"
	for item in "${SUMMARY_WARNINGS[@]}"; do
		echo "  ! $item"
	done
fi

echo -e "───────────────────────────────"
echo -e "\n${YELLOW}${BOLD}Manual steps required — see README for details:${RESET}"
echo "  · Set up 1Password and enable the SSH agent"
echo "  · Enable 1Password commit signing in developer settings"
echo -e "───────────────────────────────\n"
