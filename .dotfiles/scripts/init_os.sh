#!/usr/bin/env bash

set -euo pipefail

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
  local default=${2:-N}

  if $DRYRUN; then
    echo -e "  ${YELLOW}[DRYRUN]${RESET} Would prompt: $prompt (defaulting to $default)"
    [[ "$default" == "y" ]]
    return
  fi

  read -r -p "$prompt [y/N] " response
  [[ "${response:-$default}" == "y" ]]
}

## -- SCRIPT BEGIN -- ##

echo -e "\n${BOLD}Let's get this computer setup!${RESET}\n"

## Dotfiles

info "Checking for dotfiles..."

if [[ ! -e "$HOME/.dotfiles.git" ]]; then
  warning "dotfiles not found, cloning..."
  dryrun_safe_exec git clone --bare --recurse-submodules https://github.com/naydichev/dotfiles.git "$HOME/.dotfiles.git"
  dryrun_safe_exec git --git-dir="$HOME/.dotfiles.git" --work-tree="$HOME" checkout
  dryrun_safe_exec git --git-dir="$HOME/.dotfiles.git" --work-tree="$HOME" config status.showUntrackedFiles no
  SUMMARY_INSTALLED+=("dotfiles")
else
  success "dotfiles found"
  SUMMARY_FOUND+=("dotfiles")
fi

## Oh My Zsh

info "Checking for oh-my-zsh..."

if [[ ! -e "$HOME/.oh-my-zsh" ]]; then
  warning "oh-my-zsh not found, installing..."
  dryrun_safe_exec sh -c '$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)'
  SUMMARY_INSTALLED+=("oh-my-zsh")
else
  success "oh-my-zsh found"
  SUMMARY_FOUND+=("oh-my-zsh")
fi

## ZSH Plugins + Powerlevel10k (via submodules)

info "Initializing dotfile submodules (powerlevel10k, zsh-autosuggestions, zsh-syntax-highlighting)..."

if [[ ! -e "$HOME/.dotfiles/zsh/themes/powerlevel10k/.git" ]]; then
  dryrun_safe_exec git --git-dir="$HOME/.dotfiles.git" --work-tree="$HOME" submodule update --init --recursive
  SUMMARY_INSTALLED+=("zsh submodules")
else
  success "submodules already initialized"
  SUMMARY_FOUND+=("zsh submodules")
fi

## Default shell

info "Checking default shell..."

if [[ "$SHELL" != "$(which zsh)" ]]; then
  warning "zsh is not the default shell, changing..."
  dryrun_safe_exec chsh -s "$(which zsh)"
  SUMMARY_INSTALLED+=("zsh as default shell")
else
  success "zsh is already the default shell"
  SUMMARY_FOUND+=("zsh as default shell")
fi

## Homebrew + Casks (macOS only)

OS=$(uname)

if [[ "$OS" != "Darwin" ]]; then
  warning "Not a mac, skipping homebrew"
  SUMMARY_SKIPPED+=("homebrew")
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
    neovim
    raycast
    readdle-spark
    spotify
    telegram
    whatsapp
  )

  CASK_LIST=$(printf "\n   - %s" "${CASKS[@]}")
  info "Going to install the following casks via homebrew:${CASK_LIST}"

  if confirm "Ready to install casks?" y; then
    dryrun_safe_exec brew install --cask "${CASKS[@]}"
    SUMMARY_INSTALLED+=("homebrew casks")
  else
    SUMMARY_SKIPPED+=("homebrew casks")
  fi
fi

## LazyVim

if confirm "Setup LazyVim?"; then
  info "Backing up existing neovim configs..."
  backup_if_exists "$HOME/.config/nvim"
  backup_if_exists "$HOME/.local/share/nvim"
  backup_if_exists "$HOME/.local/state/nvim"
  backup_if_exists "$HOME/.cache/nvim"

  info "Cloning LazyVim starter..."
  dryrun_safe_exec git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
  SUMMARY_INSTALLED+=("LazyVim")
else
  SUMMARY_SKIPPED+=("LazyVim")
fi

## .gitconfig-local

info "Checking for .gitconfig-local..."

if [[ -e "$HOME/.gitconfig-local" ]]; then
  success ".gitconfig-local found"
  SUMMARY_FOUND+=(".gitconfig-local")
else
  if $DRYRUN; then
    echo -e "  ${YELLOW}[DRYRUN]${RESET} Would prompt for git email and write ~/.gitconfig-local"
    SUMMARY_SKIPPED+=(".gitconfig-local")
  else
    read -r -p "Enter your git email address: " GIT_EMAIL
    cat >"$HOME/.gitconfig-local" <<EOF
[user]
    email = ${GIT_EMAIL}
EOF
    success "Created .gitconfig-local with email: ${GIT_EMAIL}"
    SUMMARY_INSTALLED+=(".gitconfig-local")
  fi
fi

## Switch dotfiles remote to SSH now that 1Password is set up

info "Switching dotfiles remote to SSH..."
dryrun_safe_exec git --git-dir="$HOME/.dotfiles.git" remote set-url origin git@github.com:naydichev/dotfiles.git

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

echo -e "───────────────────────────────"
echo -e "\n${YELLOW}${BOLD}Manual steps required — see README for details:${RESET}"
echo "  · Set up 1Password and enable the SSH agent"
echo "  · Enable 1Password commit signing in developer settings"
echo "  · Set up powerlevel10k (run: p10k configure)"
echo -e "───────────────────────────────\n"

