#!/usr/bin/env bash
# ------------------------------------------------------------------
# ml4w-opensuse: checks run in an openSUSE Tumbleweed container (CI).
# Run as root: bash validate.sh
#  1. every package in packages.txt / apps.txt exists in the official
#     repositories (except those marked "# @alias");
#  2. the full installation resolves (zypper --dry-run --no-recommends);
#  3. Tumbleweed's Hyprland version is >= min-hyprland.
# ------------------------------------------------------------------
set -uo pipefail

SUSE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SUSE_DIR/lists.sh"
fail=0
z() { zypper --non-interactive --gpg-auto-import-keys "$@"; }

echo "::group::Repositories"
z refresh > /dev/null
while read -r alias prio url; do
    z addrepo --refresh --priority "$prio" "$url" "$alias" > /dev/null
done < <(suse_repos)
z refresh > /dev/null
zypper --non-interactive repos --priority
echo "::endgroup::"

extra_aliases=$(suse_repos | awk '{print $1}')
declare -A allowed_extra=()
while read -r name alias; do allowed_extra[$name]=$alias; done < <(suse_extra_packages)

# Repositories in which a name (package or capability) is available
repos_for() {
    zypper --non-interactive search --provides --match-exact --details "$1" 2> /dev/null |
        awk -F'|' 'NF >= 6 && $2 !~ /Name/ { r = $NF; gsub(/^[ \t]+|[ \t]+$/, "", r); print r }' |
        sort -u
}

echo "::group::Package origin"
while read -r pkg; do
    repos=$(repos_for "$pkg")
    if [ -z "$repos" ]; then
        echo "✗ $pkg: not found"
        fail=1
        continue
    fi
    official=$(grep -vxF -f <(printf '%s\n' $extra_aliases) <<< "$repos" || true)
    if [ -n "${allowed_extra[$pkg]:-}" ]; then
        if grep -qxF "${allowed_extra[$pkg]}" <<< "$repos"; then
            if [ -n "$official" ]; then
                echo "ℹ $pkg: now available in the official repositories ($official), the @${allowed_extra[$pkg]} marker can be removed"
            else
                echo "✓ $pkg: ${allowed_extra[$pkg]} (allowed extra repository)"
            fi
        elif [ -n "$official" ]; then
            echo "ℹ $pkg: missing from ${allowed_extra[$pkg]} but available in the official repositories ($official)"
        else
            echo "✗ $pkg: expected in ${allowed_extra[$pkg]}, only found in: $repos"
            fail=1
        fi
    elif [ -z "$official" ]; then
        echo "✗ $pkg: only in an extra repository ($repos), add '# @alias' if this is intended"
        fail=1
    else
        echo "✓ $pkg: $(head -n 1 <<< "$official")"
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
ver=$(zypper --non-interactive info hyprland | awk -F': *' '/^Version/ { print $2; exit }')
ver=${ver%%-*}
if [ -z "$ver" ] || [ "$(printf '%s\n%s\n' "$min" "$ver" | sort -V | head -n 1)" != "$min" ]; then
    echo "✗ Hyprland in Tumbleweed: ${ver:-unknown}, minimum required: $min"
    fail=1
else
    echo "✓ Hyprland in Tumbleweed: $ver (minimum $min)"
fi

exit $fail
