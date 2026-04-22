export EDITOR=vim

if [[ -e "$HOME/.local/bin" ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi
