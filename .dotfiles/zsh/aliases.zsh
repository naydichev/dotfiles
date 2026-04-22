function exists() {
  which $1 &> /dev/null
  return $?
}

function make_alias() {
  if exists $2; then
    alias $1=$2
  fi
}

make_alias vim nvim
make_alias cat bat
make_alias ls lsd

if [[ -e "$HOME/.cfg" ]]; then
  alias config="$(which git) --git-dir=$HOME/.cfg/ --work-tree=$HOME"
fi
