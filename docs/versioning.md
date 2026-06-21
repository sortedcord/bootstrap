# Versioning Workflow

The Bootstrap CLI uses a semantic, git-tag-driven versioning workflow.

## 1. During Normal Development

- **Do not manually edit the `VERSION` file.**
- Develop normally using [Conventional Commits](https://www.conventionalcommits.org/) (e.g., `feat: Add new tool`, `fix: Typo in script`).
- **Note on Installers:** Adding or modifying installers in the `installers/` directory **does not** require a version bump. They are fetched dynamically from the registry when a user runs `b ware <tool>`.

## 2. When to Cut a Release

You should cut a new release when you have accumulated enough changes in the core CLI files (e.g., `bootstrap.sh`, `b.sh`, or scripts in `commands/` and `lib/`).

### Semantic Versioning Rules

- **Patch (`x.x.Z`)**: Bug fixes and internal refactors (e.g., `fix:` or `refactor:`).
- **Minor (`x.Y.0`)**: New core features or commands (e.g., `feat:`).
- **Major (`X.0.0`)**: Breaking changes to user workflows (e.g., renaming core commands, breaking backward compatibility).

## 3. How to Cut a Release

You can cut a release automatically using the release script:

```bash
./scripts/release.sh
```

Alternatively, if you are using an AI agent, you can just tell it: *"cut a release"*.

### What the Release Script Does

1. Prompts you to select the bump level (Patch, Minor, Major). If using an agent, it will automatically analyze your recent commit history and decide the appropriate level based on the conventional commit prefixes.
2. Bumps the version number (e.g., `v1.1.9` -> `v1.2.0`).
3. Writes the new version into the `VERSION` file and runs `git commit`.
4. Creates an annotated git tag (e.g., `git tag -a v1.2.0`).

## 4. How Users Receive Updates

Once you push the new tag and commit to the `master` branch:

```bash
git push origin master v1.2.0
```

The release goes live immediately. Whenever users run any `b` command, `b.sh` performs a background check against the raw `VERSION` file on the `master` branch. Because the release process automatically updates this file, the CLI detects the new version and downloads the updated files dynamically.
