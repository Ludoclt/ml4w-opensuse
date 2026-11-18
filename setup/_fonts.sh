#!/usr/bin/env bash
# ml4w-opensuse: fonts shipped by ML4W are copied to ~/.local/share/fonts
# (upstream copies them with sudo into /usr/share/fonts, outside of RPM).

mkdir -p "$HOME/.local/share/fonts"
cp -rf "$repo_path/setup/fonts/FiraCode" "$HOME/.local/share/fonts/"
cp -rf "$repo_path/setup/fonts/Fira_Sans" "$HOME/.local/share/fonts/"
cp -rf "$repo_path/setup/fonts/Material-Icons" "$HOME/.local/share/fonts/"
fc-cache -f "$HOME/.local/share/fonts" > /dev/null 2>&1 || true
