#!/usr/bin/env bash
# ------------------------------------------------------------------
# Synchronization with ML4W (run by CI, can also be run locally).
#
# 1. reads upstream's stable version (the "tag" field of its stable .dotinst);
# 2. updates the subprojects when safe (check-subprojects.sh);
# 3. guard: if the new version changes setup/ in a way that affects openSUSE,
#    it is NOT published until it has been accepted;
# 4. builds: upstream version + overlay, validated in Tumbleweed;
# 5. publishes a commit on the "stable" branch + a tag, then records the
#    state in the tooling branch.
#
# Variables: FORK_URL (required), ACCEPT_TAG, ACCEPT_SUBPROJECTS=true,
#            FORCE_BUILD=true, SKIP_VALIDATE=true, NO_PUSH=true,
#            REPORT (report file), GITHUB_OUTPUT (CI)
# ------------------------------------------------------------------
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
cd "$here"

UPSTREAM="https://github.com/mylinuxforwork/dotfiles.git"
UPSTREAM_RAW="https://raw.githubusercontent.com/mylinuxforwork/dotfiles/main"
FORK_URL=${FORK_URL:?FORK_URL is required}
REPORT=${REPORT:-$here/report.md}
TW_IMAGE=${TW_IMAGE:-registry.opensuse.org/opensuse/tumbleweed:latest}
: > "$REPORT"
work=$(mktemp -d)
trap 'git worktree remove --force "$work/stable" 2> /dev/null || true; rm -rf "$work"' EXIT

out() { [ -n "${GITHUB_OUTPUT:-}" ] && echo "$1=$2" >> "$GITHUB_OUTPUT"; echo "→ $1=$2"; }
report() { printf '%s\n' "$@" >> "$REPORT"; }

new=$(curl -fsSL "$UPSTREAM_RAW/hyprland-dotfiles-stable.dotinst" | jq -r '.tag')
old=$(tr -d '[:space:]' < state/published 2> /dev/null || true)
# Version whose setup/ was reviewed by hand (starting point of the guard)
reviewed=$(tr -d '[:space:]' < state/reviewed 2> /dev/null || true)
echo "Upstream stable: $new — published here: ${old:-none}"

blocked=false

# --- Subprojects ------------------------------------------------------
sub_flag=()
[ "${ACCEPT_SUBPROJECTS:-false}" = true ] && sub_flag=(--accept)
if ! tools/check-subprojects.sh "${sub_flag[@]}" > "$work/sub.txt"; then
    blocked=true
    report "## Subprojects to review" "" "$(cat "$work/sub.txt")" ""
    report "After review, run the workflow again with **accept_subprojects** checked." ""
fi
cat "$work/sub.txt"
lock_changed=false
git diff --quiet -- overlay/setup/opensuse/subprojects.lock || lock_changed=true

# --- Guard on the new upstream version -------------------------------
target=$new
base=${old:-$reviewed}
if [ -n "$base" ] && [ "$new" != "$base" ] && [ "${ACCEPT_TAG:-}" != "$new" ]; then
    git init -q "$work/gate"
    git -C "$work/gate" fetch -q --depth=1 "$UPSTREAM" "refs/tags/$base:refs/tags/$base" "refs/tags/$new:refs/tags/$new"
    if ! tools/gate.sh "$work/gate" "$base" "$new" > "$work/gate.txt"; then
        blocked=true
        target=$base
        report "## ML4W $new: setup/ changes to review" "" "$(cat "$work/gate.txt")" ""
        report "The configuration (dotfiles/) is not affected. Adapt \`overlay/\` if needed" \
            "(packages, scripts), then run the workflow again with **accept_tag = $new**." ""
    fi
fi
out blocked "$blocked"
out upstream "$new"

# --- Anything to build? -----------------------------------------------
if [ "$target" = "$old" ] && [ "$lock_changed" = false ] && [ "${FORCE_BUILD:-false}" != true ]; then
    echo "Nothing to publish."
    out published "$old"
    exit 0
fi

# --- Build ------------------------------------------------------------
git clone -q --depth=1 --branch "$target" "$UPSTREAM" "$work/up"
tools/build.sh "$work/up" "$FORK_URL" stable

if [ "${SKIP_VALIDATE:-false}" != true ]; then
    echo "Validating in $TW_IMAGE..."
    if ! docker run --rm -v "$work/up/setup/opensuse:/v:ro" "$TW_IMAGE" bash /v/validate.sh > "$work/validate.txt" 2>&1; then
        cat "$work/validate.txt"
        report "## Tumbleweed validation failed (ML4W $target)" "" '```' \
            "$(grep -E '^(✗|ℹ)' "$work/validate.txt" || tail -n 40 "$work/validate.txt")" '```' ""
        report "Fix \`overlay/setup/opensuse/packages.txt\` (package name, @alias marker...)." ""
        out blocked true
        out published "$old"
        exit 0
    fi
    grep -E '^(✓|ℹ)' "$work/validate.txt" || true
fi

# --- Publish on the stable branch -------------------------------------
if git ls-remote --exit-code --heads origin stable > /dev/null 2>&1; then
    git fetch -q origin stable
    git worktree add -q --detach "$work/stable" FETCH_HEAD
else
    git worktree add -q --detach "$work/stable"
    git -C "$work/stable" checkout -q --orphan stable-build
    git -C "$work/stable" rm -rfq . > /dev/null 2>&1 || true
fi
find "$work/stable" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
tar -C "$work/up" --exclude=./.git -cf - . | tar -C "$work/stable" -xf -

tools_rev=$(git rev-parse --short HEAD)
git -C "$work/stable" add -A
if git -C "$work/stable" diff --cached --quiet; then
    echo "The stable branch is already up to date."
else
    git -C "$work/stable" commit -q -m "Publish ML4W $target for openSUSE (tooling $tools_rev)"
    if [ "${NO_PUSH:-false}" != true ]; then
        git -C "$work/stable" push -q origin HEAD:refs/heads/stable
        stamp="$target-suse.$(date -u +%Y%m%d%H%M)"
        git -C "$work/stable" tag "$stamp"
        git -C "$work/stable" push -q origin "refs/tags/$stamp"
        echo "Published: stable branch, tag $stamp"
    fi
fi

# --- Tooling state ----------------------------------------------------
mkdir -p state
echo "$target" > state/published
echo "$target" > state/reviewed
git add state/published state/reviewed overlay/setup/opensuse/subprojects.lock
if ! git diff --cached --quiet; then
    git commit -q -m "sync: record published ML4W $target"
    [ "${NO_PUSH:-false}" != true ] && git push -q origin HEAD
fi
out published "$target"
