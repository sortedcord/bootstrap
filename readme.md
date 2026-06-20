# Bootstrap

A collection of bootstrap scripts for setting up tools and configurations I use across new machines, servers, and development environments.

The goal is simple: reduce the number of manual steps required after installing an operating system and make my setup reproducible.

## Available Scripts

| Script            | Description                                                           |
| ----------------- | --------------------------------------------------------------------- |
| `install_agy.sh`  | Installs Antigravity CLI and triggers native shell configuration.     |
| `install_node.sh` | Installs Node.js (LTS) and NVM (Node Version Manager).                 |
| `install_nvim.sh` | Installs Neovim 0.11.7 and clones my Neovim configuration repository. |
| `install_yazi.sh` | Installs Yazi terminal file manager and its dependencies.             |
| `install_zoxide.sh` | Installs Zoxide directory jumper and configures shell integrations.   |

All scripts support Arch Linux, Debian / Ubuntu, and Fedora.

More scripts will be added over time.

## Usage

To bootstrap a new machine and set up the `b` command tool, run the following:

```bash
curl -fsSL https://adityagupta.dev/b | bash
```

Once bootstrapped, you can run any installer script using the `b` command followed by its shortcut name. You can also chain multiple installations by separating their names with a comma:

```bash
b nvim
b yazi
b nvim,yazi
```

You can also edit configurations located in your `~/.config/` directory by running:

```bash
b con nvim
b con i3
```

It automatically fuzzy-finds the folder in case there is no exact match.


## Uninstallation

To completely remove the bootstrap helper tool and clear out the shell configurations (leaving any installed software configs intact), run:

```bash
b bye
```

Then reload your shell configuration or run `unset -f b` to clear the function definition from your current terminal session.

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

* Development environment bootstrap
* Workstation setup
* Server provisioning
* Dotfile installation
* Container and virtualization tooling
* Personal utilities

## Security

Running scripts directly from the internet is convenient but should always be approached with caution.

If you do not trust the source, inspect the script before executing it:

```bash
curl -fsSL https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master/bootstrap.sh
curl -fsSL https://git.adityagupta.dev/sortedcord/bootstrap/raw/branch/master/routes.sh
```

and review the contents before piping it into a shell.

## License

MIT
