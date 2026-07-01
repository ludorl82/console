#!/bin/bash
set -euo pipefail

# Bumps the latest vX.Y.Z tag. By default also publishes a GitHub Release
# from it, targeting main -- publishing the release is what triggers
# publish-image.yaml (on: release: types: [published]), which does the
# actual multi-arch build/push.
#
# With --tag-only, only the git tag is created (no Release object, so
# publish-image.yaml does NOT trigger). Used by the scheduled patch
# rebuild, which needs to build the image itself with --pull/--no-cache
# to force apt-get to actually re-run -- publish-image.yaml's cached
# build would otherwise just replay stale layers and apply no fixes.
#
# Usage: bump-tag.sh <minor|patch> [--tag-only]
# Writes new_tag=<tag> to $GITHUB_OUTPUT when running in Actions.

BUMP_TYPE="${1:?Usage: bump-tag.sh <minor|patch> [--tag-only]}"
TAG_ONLY="${2:-}"

git fetch --tags --quiet
latest=$(git tag -l 'v*.*.*' | sort -V | tail -n1)
if [ -z "$latest" ]; then
    latest="v0.0.0"
fi

ver="${latest#v}"
IFS='.' read -r major minor patch <<< "$ver"

case "$BUMP_TYPE" in
    minor)
        minor=$((minor + 1))
        patch=0
        ;;
    patch)
        patch=$((patch + 1))
        ;;
    *)
        echo "Unknown bump type: $BUMP_TYPE (expected 'minor' or 'patch')" >&2
        exit 1
        ;;
esac

new_tag="v${major}.${minor}.${patch}"
echo "Bumping $latest -> $new_tag ($BUMP_TYPE)"

git tag "$new_tag"
git push origin "$new_tag"

if [ "$TAG_ONLY" != "--tag-only" ]; then
    gh release create "$new_tag" --target main --title "$new_tag" --generate-notes
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "new_tag=$new_tag" >> "$GITHUB_OUTPUT"
fi
