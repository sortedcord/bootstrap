# Bootstrap

A collection of bootstrap scripts for setting up tools and configurations I use across new machines, servers, and development environments.

The goal is simple: reduce the number of manual steps required after installing an operating system and make my setup reproducible.

## Available Scripts

Bootstrap is designed to be completely **environment-agnostic** and self-contained. Each bootstrap script automatically detects your platform (supporting Arch Linux, Debian/Ubuntu, Fedora, etc.) and architecture, installs the necessary dependencies using the native package manager or verified binary downloads, and cleanly configures your shell environment. This removes the overhead of maintaining multi-platform scripts and eliminates the need to run raw, complex pipelines from the web.

Here is a comparison of the size and complexity of using Bootstrap (`to b`) versus running the original, official installation scripts (`not to b`):

| application | to b | not to b |
| :--- | :--- | :--- |
| **Antigravity CLI (`agy`)** | 197 lines | 239 lines (Official Antigravity install script) |
| **asciicinema (`asciicinema`)** | 99 lines | N/A (Official binary distribution) |
| **Bat (`bat`)** | 155 lines | N/A (Standard package install) |
| **Node.js & NVM (`node`)** | 156 lines | 507 lines (Official NVM install script) |
| **Neovim (`nvim`)** | 178 lines | N/A (Official binary/config distribution) |
| **PNPM (`pnpm`)** | 245 lines | 213 lines (Official get.pnpm.io script) |
| **Rust (`rust`)** | 155 lines | 921 lines (Official sh.rustup.rs script) |
| **Starship (`starship`)** | 132 lines | 554 lines (Official starship.rs script) |
| **uv (`uv`)** | 139 lines | 2184 lines (Official uv install script) |
| **Yay (`yay`)** | 96 lines | N/A (Official manual build process) |
| **Yazi (`yazi`)** | 163 lines | N/A (Standard package install) |
| **Zoxide (`zoxide`)** | 90 lines | 466 lines (Official zoxide install script) |

More scripts will be added over time.

## Usage

To bootstrap a new machine and set up the `b` command tool, run the following:

```bash
curl -fsSL https://adityagupta.dev/b | bash
```

Once bootstrapped, you list all commands available -

```bash
b all
```

### Inspecting and Editing Installers (`b ware`)

If you want to inspect and edit an installer script before running it (for example, to change version numbers, paths, or customize the logic), you can use the intermediate `b ware` command:

```bash
b ware nvim
b ware starship,zoxide
```

This opens the installer script in your preferred `$EDITOR` (defaulting to standard terminal editors if `$EDITOR` is unset). After you edit and close the file, the modified script runs automatically.

To bypass the editor and install the tool directly using the `ware` command, append the `-y` flag:

```bash
b ware nvim -y
# or directly:
b nvim
```

To list all available installer tools and their descriptions, run the `ware` (or `bware`) command without any arguments:

```bash
b ware
```

### Editing Configurations (`b con`)

You can also edit configurations located in your `~/.config/` directory by running:

```bash
b con nvim
b con i3
```

It automatically fuzzy-finds the folder in case there is no exact match. Also, in case there is only a singular config file in that folder, then it will directly open that file.

### Rollbacks and Savepoints (`b rb` and `b fall`)

Bootstrap CLI features a powerful, procedural rollback system. It strictly tracks every extracted binary, configuration snippet, and package manager transaction to ensure your environment stays clean.

To safely uninstall the very last tool you installed (including wiping its shell paths and aliases):

```bash
b rb
```

To create a named savepoint before experimenting with your setup:

```bash
b fall pre_dev_setup
```

To completely roll back all installations made after that savepoint, restoring your system back to that exact state:

```bash
b rb pre_dev_setup
```

### Updating

To check for updates and update the tool manually:

```bash
b up
# Or to force a reinstall of the CLI files:
b up --force
```

### Plugins (`b <plugin_name>`)

Plugins are first-party or third-party applications written to work directly with `bootstrap`. Unlike installers (or packages) which modify your system by compiling code, downloading binaries, and altering shell configuration files, **plugins are lazy-loaded scripts that execute within a subshell**. 

Downloading and invoking a plugin makes no system modifications other than caching the `.sh` file itself. They are fetched only the very first time you invoke them.

To manage plugin repositories, run:

```bash
b plugin sources
```

This opens a configuration file in your `$EDITOR`. You can add raw URLs pointing to JSON plugin manifests from any repository. Once you close the editor, `bootstrap` automatically parses those manifests using its native JSON parser and generates a fast, zero-latency lookup cache.

You can then execute a plugin simply by calling its name:

```bash
b my_plugin
```

Plugins are automatically checked for updates and lazily re-downloaded whenever you run `b up`.

For documentation on how to develop and publish your own plugins, please see the [Plugin Development Guide](docs/plugin_development.md).

## Uninstallation

To uninstall the bootstrap helper tool but leave a lightweight `b back` function to easily reinstall it later:

```bash
b gone
```

To completely remove the bootstrap helper tool, clear out all shell configurations (including the `b back` shortcut), and leave nothing behind:

```bash
b gone -f
```

Then reload your shell configuration or run `unset -f b` to clear the function definition from your current terminal session.

## Development

If you are developing this tool locally:

1. Clone the repository.
2. Run `./bootstrap.sh` to install the CLI from your local copy. This will also automatically install a Git pre-commit hook (`scripts/pre-commit`) that auto-increments the patch version in the `VERSION` file on each commit.

## Philosophy

These scripts are designed for my own systems first.

That means they may make assumptions about:

* Preferred software choices
* Directory layouts
* Configuration locations
* Existing infrastructure

The scripts are intentionally straightforward Bash scripts that can be inspected and modified before execution.

## Future Plans

Potential additions include:

* RSA based authentication
* Development environment bootstrap
* Workstation setup
* Server provisioning
* Dotfile installation
* Container and virtualization tooling
* Personal utilities

## Security

Running scripts directly from the internet is convenient but should always be approached with caution.

### Why Bootstrap is More Secure
Instead of blindly piping large, third-party installation scripts (often hundreds or thousands of lines of unscrutinized code) directly from the internet into your shell, Bootstrap uses a **scrutinized and simplified** approach:

1. **Audited & Minimised**: Every script in `installers/` has been scrutinized, refactored, and stripped of redundant compatibility layers (like Windows/macOS support or complex environment checks), leaving only the essential, readable logic required for your setup.
2. **Controlled Execution**: Since installer scripts are hosted locally in your cloned repository, you can review every line of code before executing it. You are never subject to silent, upstream changes to installers.
3. **No Raw Pipes**: We download official binary releases directly to verified temporary locations rather than running arbitrary third-party script pipelines.

If you want to audit the core Bootstrap CLI itself before running it:

```bash
curl -fsSL https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master/bootstrap.sh
curl -fsSL https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master/lib/routes.sh
```

and review the contents before piping it into a shell.

## Should I Use It?

Hell no, go make your own.

## License

MIT
