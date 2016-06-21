#!/bin/bash

OS=$(uname);
BPATH="$HOME/.bashrc.";
BASHRC=".bashrc.";

EXCEPTION=("${BASHRC}amazon", "${BASHRC}${OS}");

EX_STR=""
for name in "${EXCEPTION[@]}"; do
    EX_STR="$EX_STR -and -not -name ${name/,/}";
done

FILES=$(find $HOME -maxdepth 1 -type l -name "${BASHRC}*" $EX_STR);
echo "Clearing non-essential ${BASHRC/%./} files: $FILES"

if [ -n "$FILES" ]; then
    echo $FILES | xargs unlink
fi
