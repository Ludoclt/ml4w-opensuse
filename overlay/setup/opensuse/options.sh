#!/usr/bin/env bash
# ml4w-opensuse options (1 = enabled, 0 = disabled)

# Replace the ML4W logo (Waybar, Quickshell, fastfetch) with the openSUSE Geeko
ML4W_SUSE_GEEKO=1

# Logo URL (the openSUSE chameleon; for the Tumbleweed logo use
# https://raw.githubusercontent.com/openSUSE/distribution-logos/master/Tumbleweed/square-hicolor.svg)
ML4W_SUSE_GEEKO_URL="https://raw.githubusercontent.com/openSUSE/artwork/master/logos/official/geeko-color.svg"

# Pywalfox: theme colors in Firefox (useless if you don't use Firefox)
ML4W_SUSE_PYWALFOX=0

# Minimum matugen version (installed with cargo into ~/.cargo/bin)
ML4W_SUSE_MATUGEN_MIN="4.0.0"

# Browser opened by ML4W shortcuts (upstream: firefox; empty = firefox).
# Only sets the initial value: your choice in ML4W Settings is kept afterwards.
# Brave is installed from its official repository (repos.txt, packages.txt).
ML4W_SUSE_BROWSER="brave-browser"
