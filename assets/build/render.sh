#!/bin/zsh
# usage: render.sh in.html width height out.png
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files --force-device-scale-factor=1 --window-size=$2,$3 --screenshot="$4" "file://$1" >/dev/null 2>&1
