#!/usr/bin/env bash
# ------------------------------------------------------------------
# ml4w-opensuse: replaces upstream's generic post.sh.
# Same components as upstream, but:
#  - subproject install scripts are pinned (subprojects.lock); CI reviews
#    every new version before letting it through;
#  - ML4W Dotfiles Settings is installed with "make install" (into ~/.local),
#    without its setup.sh, which runs sudo zypper;
#  - Walker is installed with --no-deps (its libraries are in packages.txt);
#  - everything goes to ~/.local, nothing to /usr.
# ------------------------------------------------------------------

source "$repo_path/setup/opensuse/lists.sh"
export PATH="$HOME/.local/bin:$PATH"

# --- Oh My Posh (official installer, into ~/.local/bin) ---------------
curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin"

# --- ML4W Dotfiles Settings -------------------------------------------
read -r _repo _file _sha < <(suse_lock_get ml4w-dotfiles-settings)
_tmp=$(mktemp -d)
if git clone --quiet "https://github.com/$_repo.git" "$_tmp" && git -C "$_tmp" checkout --quiet "$_sha"; then
    make -C "$_tmp" install
else
    warn "ML4W Dotfiles Settings: clone failed"
fi
rm -rf "$_tmp"
unset _repo _file _sha _tmp

# --- Subprojects (Quickshell, in ~/.local/share) ----------------------
suse_run_subproject ml4w-quickshell-overview
suse_run_subproject hypr-app-switcher
suse_run_subproject ml4w-dock
suse_run_subproject ml4w-powermenu
suse_run_subproject ml4w-walker --providers desktopapplications,menus,clipboard --no-deps

# --- Cursors, fonts, icons (in ~/.local/share) ------------------------
source "$repo_path/setup/_cursors.sh"
source "$repo_path/setup/_fonts.sh"
source "$repo_path/setup/_icons.sh"

# --- XDG user directories ---------------------------------------------
xdg-user-dirs-update
