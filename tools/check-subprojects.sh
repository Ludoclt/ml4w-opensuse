#!/usr/bin/env bash
# ------------------------------------------------------------------
# Updates overlay/setup/opensuse/subprojects.lock.
#
# For each subproject (dock, walker, settings...): if its install script
# changed upstream, look at the added lines.
#  - nothing touching the system -> the pinned commit is updated;
#  - sudo, package manager, /usr, /etc, system pip, curl|sh...
#    -> the lock entry is left unchanged, the diff is printed and the
#       script exits with 1 (review needed).
#
#   tools/check-subprojects.sh            # check and update
#   tools/check-subprojects.sh --accept   # accept everything (after review)
# ------------------------------------------------------------------
set -euo pipefail

accept=false
[ "${1:-}" = "--accept" ] && accept=true

here=$(cd "$(dirname "$0")/.." && pwd)
lock="$here/overlay/setup/opensuse/subprojects.lock"
danger='(\bsudo\b|\bzypper\b|\bpacman\b|\bdnf\b|\bapt(-get)?\b|\brpm\b|/usr/|/etc/|--break-system-packages|\bpip3? install\b|systemctl (enable|--system)|curl[^|]*\|[[:space:]]*(ba)?sh|wget[^|]*\|[[:space:]]*(ba)?sh)'
status=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

while read -r name repo file sha; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    latest=$(git ls-remote "https://github.com/$repo.git" HEAD | cut -f1)
    if [ -z "$latest" ]; then
        echo "⚠ $name: cannot reach $repo"
        continue
    fi
    [ "$latest" = "$sha" ] && { echo "✓ $name: up to date (${sha:0:7})"; continue; }

    curl -fsSL "https://raw.githubusercontent.com/$repo/$sha/$file" -o "$tmp/old" || : > "$tmp/old"
    curl -fsSL "https://raw.githubusercontent.com/$repo/$latest/$file" -o "$tmp/new"

    if cmp -s "$tmp/old" "$tmp/new"; then
        sed -i "s/$sha/$latest/" "$lock"
        echo "↻ $name: ${sha:0:7} → ${latest:0:7} ($file unchanged)"
        continue
    fi

    added=$(diff "$tmp/old" "$tmp/new" | sed -n 's/^> //p' || true)
    if [ "$accept" = false ] && grep -Eq "$danger" <<< "$added"; then
        status=1
        echo "✗ $name: $file changed and touches the system (${sha:0:7} → ${latest:0:7}). Review needed:"
        echo
        echo '```diff'
        diff -u "$tmp/old" "$tmp/new" | sed "1,2s|$tmp/||" || true
        echo '```'
        echo
    else
        sed -i "s/$sha/$latest/" "$lock"
        echo "↻ $name: ${sha:0:7} → ${latest:0:7} ($file changed, nothing touching the system)"
    fi
done < "$lock"

exit $status
