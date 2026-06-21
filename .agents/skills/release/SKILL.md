---
name: release
description: >
  Cut a new release of the bootstrap CLI. Use this skill when the user asks
  to bump the version, tag a release, or cut a new version. Analyzes recent
  commits to determine the appropriate semver bump level and runs
  scripts/release.sh automatically.
---

# Release Skill

This skill automates the versioning and release process for the bootstrap CLI.

## Workflow

When the user asks to "cut a release", "bump the version", or "tag a new version":

1. **Analyze commits since the last tag**:
   ```bash
   git log $(git describe --tags --abbrev=0)..HEAD --oneline
   ```
2. **Determine the bump level** using semantic versioning rules:
   - Skip any commits that only touch `installers/` or docs — those don't warrant a bump.
   - If any commit has `BREAKING CHANGE` or `!:` → **major**
   - If any core-CLI commit has `feat:` → **minor**
   - Otherwise (only `fix:`, `refactor:`, etc. in core-CLI) → **patch**
   - If *all* commits are installer-only or docs-only → inform the user no release is needed.
3. **Run the release script** non-interactively (if an actual bump is needed):
   ```bash
   ./scripts/release.sh --<level> -y
   ```
   (e.g., `./scripts/release.sh --minor -y`)
4. **Push** the tag and commit (ask for user confirmation before pushing):
   ```bash
   git push origin master <tag>
   ```

## Dry-run Mode

If the user asks "what would the next version be?" or similar, do the analysis (steps 1 and 2) but do NOT run the release script. Just report the recommended bump level and why.
