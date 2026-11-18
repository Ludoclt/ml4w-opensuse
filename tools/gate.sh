#!/usr/bin/env bash
# ------------------------------------------------------------------
# Guard: upstream changes in setup/ that affect openSUSE.
#
#   tools/gate.sh <upstream_git_repo> <old_tag> <new_tag>
#
# Changes in dotfiles/ (the configuration) always go through.
# Changes in setup/ (what runs as root, repositories, packages) must be
# reviewed: the diff is printed and the script exits with 1.
# Arch, Fedora and Ubuntu specific files are ignored.
# ------------------------------------------------------------------
set -euo pipefail

repo=${1:?repository}
old=${2:?old tag}
new=${3:?new tag}

paths=(setup
    ':(exclude)setup/*arch*' ':(exclude)setup/*fedora*' ':(exclude)setup/*ubuntu*'
    ':(exclude)setup/fonts' ':(exclude)setup/cursors')

if git -C "$repo" diff --quiet "$old" "$new" -- "${paths[@]}"; then
    echo "No upstream change in setup/ affecting openSUSE between $old and $new."
    exit 0
fi

echo "Upstream changes in setup/ between $old and $new:"
echo
git -C "$repo" diff --stat "$old" "$new" -- "${paths[@]}"
echo
echo '```diff'
git -C "$repo" diff "$old" "$new" -- "${paths[@]}"
echo '```'
exit 1
