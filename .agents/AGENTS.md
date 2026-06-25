# Bootstrap Project Rules

## Repository Cleanliness & Runtime Separation
- **No Repository Clutter**: Do not commit, track, or create runtime configuration, cache, or temporary files in the repository root.
- **Dynamic Initialization**: All runtime-generated files (such as `plugin_sources.txt`, `lib/plugin_cache.sh`, or local plugin downloads) must reside strictly under the user's active `$BOOTSTRAP_DIR` (e.g., `~/.config/bootstrap`). The CLI must auto-generate or initialize these files dynamically at runtime if they are missing, ensuring a zero-configuration out-of-the-box experience.
