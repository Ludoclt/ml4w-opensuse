#!/usr/bin/env bash
# ------------------------------------------------------------------
# ml4w-opensuse: helpers shared by the setup scripts and CI.
# This file is sourced; it must not execute anything on its own.
# Only bash, sed and tr are used: minimal Tumbleweed images have no awk.
# ------------------------------------------------------------------

SUSE_DIR="${SUSE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# Words of a file, without comments or empty lines
_suse_words() {
    sed 's/#.*//' "$1" | tr -s ' \t' '\n' | sed '/^$/d'
}

# System packages (installed on every install and update)
suse_packages() { _suse_words "$SUSE_DIR/packages.txt"; }

# Suggested applications (installed once, on the initial installation)
suse_apps() { _suse_words "$SUSE_DIR/apps.txt"; }

# Packages allowed to come from an extra repository: "name alias"
# (marked "# @alias" in packages.txt)
suse_extra_packages() {
    sed -n 's/^[[:space:]]*\([^#[:space:]]\+\)[[:space:]]*#[[:space:]]*@\([^[:space:]]\+\).*/\1 \2/p' \
        "$SUSE_DIR/packages.txt"
}

# Extra repositories: "alias priority url key_url" (key_url may be empty)
suse_repos() {
    local line alias prio url key
    while IFS= read -r line || [ -n "$line" ]; do
        line=${line%%#*}
        [[ "$line" == *"|"*"|"* ]] || continue
        IFS='|' read -r alias prio url key <<< "$line"
        echo "${alias//[[:space:]]/} ${prio//[[:space:]]/} ${url//[[:space:]]/} ${key//[[:space:]]/}"
    done < "$SUSE_DIR/repos.txt"
}

# Pinned ML4W subproject: "repository file commit" for a given name
suse_lock_get() {
    local name repo file sha
    while read -r name repo file sha; do
        [ "$name" = "$1" ] && { echo "$repo $file $sha"; return 0; }
    done < "$SUSE_DIR/subprojects.lock"
}

# Run a subproject's install script at its pinned commit
suse_run_subproject() {
    local name=$1 repo file sha
    shift
    read -r repo file sha < <(suse_lock_get "$name")
    if [ -z "$sha" ]; then
        echo ":: [ml4w-opensuse] $name is missing from subprojects.lock, skipped"
        return 0
    fi
    echo ":: [ml4w-opensuse] $name ($repo@${sha:0:7})"
    bash <(curl -fsSL "https://raw.githubusercontent.com/$repo/$sha/$file") "$@"
}
