#!/usr/bin/env bash
# ------------------------------------------------------------------
# Applies the openSUSE overlay on top of an upstream checkout (ML4W dotfiles).
#
#   tools/build.sh <upstream_dir> <fork_git_url> [branch]
#
# - copies overlay/ on top (openSUSE setup scripts);
# - empties upstream's package lists (replaced by setup/opensuse/packages.txt
#   and apps.txt, installed without Recommends);
# - generates ml4w-opensuse.dotinst from upstream's stable .dotinst
#   (so the "restore" list always follows upstream).
# ------------------------------------------------------------------
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
up=${1:?upstream directory}
fork_url=${2:?fork url}
branch=${3:-stable}

dotinst="$up/hyprland-dotfiles-stable.dotinst"
[ -f "$dotinst" ] || { echo "Not an ML4W checkout: $up" >&2; exit 1; }
upstream_tag=$(jq -r '.tag' "$dotinst")

cp -a "$here/overlay/." "$up/"

for f in setup/dependencies/packages setup/dependencies/packages-opensuse \
    setup/packages/packages setup/packages/packages-opensuse; do
    mkdir -p "$(dirname "$up/$f")"
    printf '# Managed by ml4w-opensuse: see setup/opensuse/packages.txt and apps.txt\n' > "$up/$f"
done

jq --arg src "$fork_url" --arg br "$branch" --arg v "$upstream_tag" '
    .name = ("ML4W OS for openSUSE Tumbleweed (upstream " + $v + ")")
    | .id = "com.ml4w.dotfiles.opensuse"
    | .source = $src
    | .tag = $br
    | .version = $v' "$dotinst" > "$up/ml4w-opensuse.dotinst"

echo "$upstream_tag" > "$up/setup/opensuse/UPSTREAM_TAG"
echo "openSUSE overlay applied on ML4W $upstream_tag"
