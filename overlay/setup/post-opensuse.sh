#!/usr/bin/env bash
# ------------------------------------------------------------------
# ml4w-opensuse: replaces upstream's post-opensuse.sh.
# Everything that does not come from an RPM is installed in $HOME:
#  - nwg-displays: pipx (instead of pip --break-system-packages);
#  - matugen: cargo, in ~/.cargo/bin;
#  - grimblast: ~/.local/bin (instead of sudo make install);
#  - awww and quickshell: RPMs, already installed by preflight-opensuse.sh.
# This script runs BEFORE the dotfiles are copied: changes made inside
# $repo_path (logo, default browser) are therefore reapplied on every update.
# ------------------------------------------------------------------

source "$repo_path/setup/opensuse/lists.sh"
source "$repo_path/setup/opensuse/options.sh"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# --- nwg-displays -----------------------------------------------------
if pipx list --short 2> /dev/null | grep -q '^nwg-displays '; then
    pipx upgrade nwg-displays || warn "nwg-displays: upgrade failed"
else
    pipx install --system-site-packages "git+https://github.com/nwg-piotr/nwg-displays.git" ||
        warn "nwg-displays: installation failed"
fi

# --- matugen ----------------------------------------------------------
_current=$(matugen --version 2> /dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
if [ -z "$_current" ] ||
    [ "$(printf '%s\n%s\n' "$ML4W_SUSE_MATUGEN_MIN" "$_current" | sort -V | head -n 1)" != "$ML4W_SUSE_MATUGEN_MIN" ]; then
    info "Installing matugen (cargo, ~/.cargo/bin)..."
    cargo install matugen --force
else
    info "matugen $_current is up to date"
fi
unset _current

# --- Pywalfox (optional) ----------------------------------------------
if [ "$ML4W_SUSE_PYWALFOX" = 1 ]; then
    pipx install pywalfox 2> /dev/null || pipx upgrade pywalfox
    pywalfox install
fi

# --- grimblast --------------------------------------------------------
source "$repo_path/setup/clean-install-grimblast.sh"

# --- Default browser --------------------------------------------------
# settings/ is in the installer's "restore" list: the user's choice is kept
# across updates, this only changes the initial value.
if [ -n "${ML4W_SUSE_BROWSER:-}" ]; then
    echo "$ML4W_SUSE_BROWSER" > "$repo_path/dotfiles/.config/ml4w/settings/browser.sh"
    sed -i "s/\"default\": \"firefox\"/\"default\": \"$ML4W_SUSE_BROWSER\"/" \
        "$repo_path/dotfiles/.config/ml4w-dotfiles-settings/com.ml4w.dotfiles/settings.json"
    xdg-settings set default-web-browser "$ML4W_SUSE_BROWSER.desktop" 2> /dev/null || true
fi

# --- Sidebar button in the "default" and "starter" Waybar themes -------
# Upstream still points these two themes to the old sidebar (a missing
# script and a Flatpak); the other themes use the Quickshell sidebar.
_wb="$repo_path/dotfiles/.config/waybar/themes"
sed -i -e 's#"sleep 0.1 \&\& ~/.config/ml4w/settings/ml4w-sidebar.sh"#"qs ipc call sidebar toggle"#' \
    -e 's#"sleep 0.1 \&\& com.ml4w.welcome"#"qs ipc call welcome toggle"#' "$_wb/default/config"
sed -i -e 's#"flatpak run com.ml4w.sidebar"#"qs ipc call sidebar toggle"#' \
    -e 's#"flatpak run com.ml4w.welcome"#"qs ipc call welcome toggle"#' "$_wb/starter/modules.json"
unset _wb

# --- openSUSE logo instead of the ML4W logo ---------------------------
# The logo is downloaded from the official openSUSE repository instead of
# being committed here (registered trademark, "all rights reserved").
if [ "$ML4W_SUSE_GEEKO" = 1 ]; then
    _geeko_dir="$HOME/.local/share/ml4w-opensuse"
    _geeko="$_geeko_dir/logo.svg"
    mkdir -p "$_geeko_dir"
    if [ ! -s "$_geeko" ] || [ "$(cat "$_geeko_dir/logo.url" 2> /dev/null)" != "$ML4W_SUSE_GEEKO_URL" ]; then
        curl -fsSL "$ML4W_SUSE_GEEKO_URL" -o "$_geeko" && echo "$ML4W_SUSE_GEEKO_URL" > "$_geeko_dir/logo.url"
    fi
    if [ -s "$_geeko" ] && command -v rsvg-convert > /dev/null; then
        _cfg="$repo_path/dotfiles/.config"
        _color=$(grep -Eo 'fill="#[0-9a-fA-F]{6}"' "$_geeko" | head -n 1 | cut -d'"' -f2)
        cp -f "$_geeko" "$_cfg/waybar/assets/ml4w-icon.svg"
        cp -f "$_geeko" "$_cfg/ml4w/assets/ml4w.svg"
        cp -f "$_geeko" "$_cfg/quickshell/shared/ml4w.svg"
        if [ -n "$_color" ]; then
            sed "s/$_color/#ffffff/g" "$_geeko" > "$_cfg/waybar/assets/ml4w-icon-white.svg"
            sed "s/$_color/#000000/g" "$_geeko" > "$_cfg/waybar/assets/ml4w-icon-black.svg"
        fi
        rsvg-convert -h 20 "$_geeko" -o "$_cfg/waybar/assets/ml4w-icon-20.png"
        rsvg-convert -w 512 "$_geeko" -o "$_cfg/ml4w/assets/ml4w.png"
        info "ML4W logo replaced with the openSUSE logo"
    else
        warn "openSUSE logo unavailable, keeping the ML4W logo"
    fi
    unset _geeko_dir _geeko _cfg _color
fi
