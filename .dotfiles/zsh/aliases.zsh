function exists() {
  command -v "$1" &> /dev/null
}

function make_alias() {
  if exists $2; then
    alias $1=$2
  fi
}

make_alias vim nvim
make_alias cat bat
make_alias ls lsd

DOTFILES_REPO="$HOME/.dotfiles.git"

if [[ -e "$DOTFILES_REPO" ]]; then
  alias dit="$(which git) --git-dir=$DOTFILES_REPO --work-tree=$HOME"
fi
