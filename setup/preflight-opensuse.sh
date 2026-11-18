#!/usr/bin/env bash
# ------------------------------------------------------------------
# ml4w-opensuse: replaces upstream's preflight-opensuse.sh.
# Sourced by ml4w-dotfiles-installer on every install and update.
#
# Differences from upstream:
#  - no X11:Wayland, X11:fonts, KDE:Qt6 or duplicate OSS repository;
#  - extra repositories at low priority, signing keys confirmed by hand;
#  - a single zypper transaction, without Recommends;
#  - oh-my-posh is installed only once (in post.sh).
# ------------------------------------------------------------------

source "$repo_path/setup/opensuse/lists.sh"

ensure_sudo 2> /dev/null || sudo -v

# --- Extra repositories (low priority) ------------------------------
while read -r _alias _prio _url _key; do
    if [ -f "/etc/zypp/repos.d/$_alias.repo" ]; then
        sudo zypper --quiet modifyrepo --priority "$_prio" "$_alias"
    else
        info "Adding repository $_alias (priority $_prio)"
        if [ -n "$_key" ]; then
            info "Importing the signing key of $_alias from $_key"
            sudo rpm --import "$_key"
        fi
        sudo zypper addrepo --refresh --priority "$_prio" "$_url" "$_alias"
        # Interactive refresh: zypper shows the repository key fingerprint.
        # Check it before accepting (no automatic key import).
        sudo zypper refresh "$_alias"
    fi
done < <(suse_repos)

# --- System packages ------------------------------------------------
mapfile -t _suse_pkgs < <(suse_packages)
info "Installing ${#_suse_pkgs[@]} packages (zypper --no-recommends)..."
sudo zypper --non-interactive install --no-recommends "${_suse_pkgs[@]}"

# --- Suggested applications: initial installation only ---------------
if [ "${is_update:-false}" != true ]; then
    mapfile -t _suse_apps < <(suse_apps)
    if [ ${#_suse_apps[@]} -gt 0 ]; then
        info "Installing suggested applications: ${_suse_apps[*]}"
        sudo zypper --non-interactive install --no-recommends "${_suse_apps[@]}"
    fi
fi

# --- System services --------------------------------------------------
for _svc in bluetooth power-profiles-daemon; do
    systemctl is-enabled --quiet "$_svc" 2> /dev/null || sudo systemctl enable --now "$_svc"
done
if ! systemctl is-enabled --quiet NetworkManager 2> /dev/null; then
    if systemctl is-active --quiet wicked 2> /dev/null; then
        warn "Networking is managed by wicked. To switch to NetworkManager:"
        warn "  sudo systemctl disable --now wicked && sudo systemctl enable --now NetworkManager"
    else
        sudo systemctl enable --now NetworkManager
    fi
fi

unset _alias _prio _url _key _suse_pkgs _suse_apps _svc
