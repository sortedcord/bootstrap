#!/usr/bin/env bash
# scripts/release.sh — Tag a new release
# Usage:
#   Interactive:      ./scripts/release.sh
#   Non-interactive:  ./scripts/release.sh --patch|--minor|--major [-y]
set -euo pipefail

current=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
IFS='.' read -r cur_major cur_minor cur_patch <<< "${current#v}"

bump=""
auto_confirm=false

# Parse flags for non-interactive (agent) usage
while [[ $# -gt 0 ]]; do
    case "$1" in
        --patch) bump="patch"; shift ;;
        --minor) bump="minor"; shift ;;
        --major) bump="major"; shift ;;
        -y|--yes) auto_confirm=true; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

echo "Current version: $current"

# Interactive fallback if no flag provided
if [ -z "$bump" ]; then
    echo ""
    echo "What type of release?"
    echo "  1) patch  (bug fixes, internal changes)"
    echo "  2) minor  (new features, new commands)"
    echo "  3) major  (breaking changes)"
    read -rp "Choice [1/2/3]: " choice
    case "$choice" in
        1) bump="patch" ;;
        2) bump="minor" ;;
        3) bump="major" ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac
fi

case "$bump" in
    patch) cur_patch=$((cur_patch + 1)) ;;
    minor) cur_minor=$((cur_minor + 1)); cur_patch=0 ;;
    major) cur_major=$((cur_major + 1)); cur_minor=0; cur_patch=0 ;;
esac

new_ver="v${cur_major}.${cur_minor}.${cur_patch}"

if [ "$auto_confirm" = true ]; then
    confirm="y"
else
    read -rp "Tag as $new_ver? [y/N]: " confirm
fi

if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "${new_ver#v}" > VERSION
    git add VERSION
    git commit -m "release: $new_ver"
    git tag -a "$new_ver" -m "Release $new_ver"
    echo "Tagged $new_ver. Push with: git push origin master $new_ver"
else
    echo "Aborted."
fi
