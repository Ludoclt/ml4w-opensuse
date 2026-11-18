#!/usr/bin/env bash
# ------------------------------------------------------------------
# ml4w-opensuse: checks run in an openSUSE Tumbleweed container (CI).
# Run as root: bash validate.sh
#  1. every package in packages.txt / apps.txt exists in the official
#     repositories (except those marked "# @alias");
#  2. the full installation resolves (zypper --dry-run --no-recommends);
#  3. Tumbleweed's Hyprland version is >= min-hyprland.
#
# Only bash, sed, tr and sort are used: the minimal image has no awk.
#
# Exit codes: 0 = OK, 1 = problem in the package lists,
#             2 = repositories unreachable (e.g. mirror being synced),
#                 nothing to fix, the check must simply run again later.
# ------------------------------------------------------------------
set -uo pipefail

SUSE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SUSE_DIR/lists.sh"
fail=0
z() { zypper --non-interactive --gpg-auto-import-keys "$@"; }

# Refresh all repositories, retrying while a mirror is out of sync
refresh_all() {
    local attempt
    for attempt in 1 2 3 4 5; do
        z refresh && return 0
        echo "Repository refresh failed (attempt $attempt/5), retrying in 60 s..."
        z clean --all > /dev/null 2>&1
        sleep 60
    done
    return 1
}

echo "::group::Repositories"
while read -r alias prio url; do
    z addrepo --refresh --priority "$prio" "$url" "$alias" > /dev/null
done < <(suse_repos)
if ! refresh_all; then
    echo "::endgroup::"
    echo "⚠ Could not refresh the repositories (Tumbleweed mirror out of sync?). Checks skipped."
    exit 2
fi
zypper --non-interactive repos --priority
echo "::endgroup::"

declare -A extra_alias=() allowed_extra=()
while read -r alias _; do extra_alias[$alias]=1; done < <(suse_repos)
while read -r name alias; do allowed_extra[$name]=$alias; done < <(suse_extra_packages)

# Repositories (aliases) in which a name, package or capability, is available
repos_for() {
    local _s name _t _v _a repo
    zypper --non-interactive search --provides --match-exact --details "$1" 2> /dev/null |
        while IFS='|' read -r _s name _t _v _a repo; do
            name=${name//[[:space:]]/}
            repo=$(echo $repo)
            [ -z "$repo" ] || [ "$name" = "Name" ] && continue
            echo "$repo"
        done | sort -u
}

echo "::group::Package origin"
while read -r pkg; do
    mapfile -t repos < <(repos_for "$pkg")
    if [ ${#repos[@]} -eq 0 ]; then
        echo "✗ $pkg: not found"
        fail=1
        continue
    fi
    official=()
    in_allowed=false
    for r in "${repos[@]}"; do
        [ -n "${extra_alias[$r]:-}" ] || official+=("$r")
        [ "$r" = "${allowed_extra[$pkg]:-}" ] && in_allowed=true
    done
    if [ -n "${allowed_extra[$pkg]:-}" ]; then
        if [ "$in_allowed" = true ] && [ ${#official[@]} -gt 0 ]; then
            echo "ℹ $pkg: now available in the official repositories (${official[*]}), the @${allowed_extra[$pkg]} marker can be removed"
        elif [ "$in_allowed" = true ]; then
            echo "✓ $pkg: ${allowed_extra[$pkg]} (allowed extra repository)"
        elif [ ${#official[@]} -gt 0 ]; then
            echo "ℹ $pkg: missing from ${allowed_extra[$pkg]} but available in the official repositories (${official[*]})"
        else
            echo "✗ $pkg: expected in ${allowed_extra[$pkg]}, only found in: ${repos[*]}"
            fail=1
        fi
    elif [ ${#official[@]} -eq 0 ]; then
        echo "✗ $pkg: only in an extra repository (${repos[*]}), add '# @alias' if this is intended"
        fail=1
    else
        echo "✓ $pkg: ${official[0]}"
    fi
done < <(suse_packages; suse_apps)
echo "::endgroup::"

echo "::group::Full resolution (dry-run)"
mapfile -t all < <(suse_packages; suse_apps)
if ! zypper --non-interactive install --dry-run --no-recommends "${all[@]}"; then
    echo "✗ zypper cannot resolve the installation"
    fail=1
fi
echo "::endgroup::"

min=$(tr -d '[:space:]' < "$SUSE_DIR/min-hyprland")
ver=$(zypper --non-interactive info hyprland | sed -n 's/^Version *: *//p' | head -n 1)
ver=${ver%%-*}
if [ -z "$ver" ] || [ "$(printf '%s\n%s\n' "$min" "$ver" | sort -V | head -n 1)" != "$min" ]; then
    echo "✗ Hyprland in Tumbleweed: ${ver:-unknown}, minimum required: $min"
    fail=1
else
    echo "✓ Hyprland in Tumbleweed: $ver (minimum $min)"
fi

exit $fail
