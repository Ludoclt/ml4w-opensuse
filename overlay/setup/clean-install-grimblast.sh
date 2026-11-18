#!/usr/bin/env bash
# ml4w-opensuse: grimblast (a shell script) is installed to ~/.local/bin
# (upstream runs "sudo make install" into /usr/local).

_grimblast_dir=$(mktemp -d)
if git clone --quiet --depth=1 https://github.com/hyprwm/contrib.git "$_grimblast_dir"; then
    install -Dm755 "$_grimblast_dir/grimblast/grimblast" "$HOME/.local/bin/grimblast"
    echo ":: grimblast installed to ~/.local/bin"
else
    echo ":: grimblast: clone failed"
fi
rm -rf "$_grimblast_dir"
unset _grimblast_dir
