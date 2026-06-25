# Plugin Development Guide

Plugins are first-party or third-party applications written to work directly with `bootstrap`. Unlike installers (or packages) which modify your system by compiling code, downloading binaries, and altering shell configuration files, **plugins are lazy-loaded scripts that execute within a sandboxed subshell**.

This means downloading and invoking a plugin makes no system modifications other than caching the `.sh` file itself. They are fetched only the very first time you invoke them.

## 1. Writing a Plugin Script

A plugin is fundamentally a single Bash script. When executed by a user via `b <plugin_name>`, `bootstrap` runs the script in a subshell. This guarantees that any variables or state changes your plugin makes to the shell environment will not leak into the parent shell, preserving the integrity of the user's terminal.

Because plugins execute within the `bootstrap` context, you automatically have access to all internal library functions (e.g., `lib/common.sh`, `lib/platform.sh`). For example, you can safely use logging functions like `log_info`, `log_success`, and `log_error`.

Example `my_plugin.sh`:

```bash
#!/usr/bin/env bash
# My Awesome Plugin

# You can use bootstrap's built-in functions natively:
log_info "Initializing awesome plugin..."

if [ "${1:-}" == "--help" ]; then
    echo "Usage: b my_plugin [args]"
    exit 0
fi

log_success "Task completed successfully!"
```

## 2. Creating a Manifest

For your plugin to be discoverable and dynamically updatable by `bootstrap`, you must provide a JSON manifest. `bootstrap` uses a robust, native Bash-based JSON parser to read this manifest.

Create a JSON file (e.g., `plugins.json`) and host it publicly (e.g., as a GitHub raw URL).

Example `plugins.json`:

```json
{
  "plugins": {
    "my_plugin": {
      "version": "1.0.0",
      "url": "https://raw.githubusercontent.com/yourusername/repo/main/my_plugin.sh",
      "bootstrap": "2.1.0",
      "description": "An awesome plugin that prints logs"
    }
  }
}
```

* **`version`**: The current semantic version of your plugin. When `bootstrap` detects a version change during `b up`, it automatically clears the cached `.sh` file, forcing a lazy re-download on the next invocation.
* **`url`**: The raw, direct URL to your `.sh` plugin script. 
* **`bootstrap`**: The latest version of `bootstrap` that this plugin has been tested against and is compatible with. If the user's `bootstrap` version is newer than this value, a warning is displayed notifying them of potential incompatibility.

## 3. Distribution

To let users install your plugin, simply provide them the raw URL to your JSON manifest.

Users will add it by running:

```bash
b plugin sources
```

They simply append your URL as a new line in the sources file. Once saved, `bootstrap` will automatically fetch your manifest and build a fast-lookup cache. The user can then immediately invoke your plugin:

```bash
b my_plugin
```
