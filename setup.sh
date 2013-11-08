#!/bin/bash

OS=`uname`;
BPATH="$HOME/.bashrc.";

for file in `ls $HOME/.bashrc.*`; do
    if [ $file != "${BPATH}load" -a $file != "${BPATH}${OS}" ]; then
        unlink $file;
    fi
done
