# Bootstrap

A collection of bootstrap scripts for setting up tools and configurations I use across new machines, servers, and development environments.

The goal is simple: reduce the number of manual steps required after installing an operating system and make my setup reproducible.

## Available Scripts

| Script            | Description                                                           |
| ----------------- | --------------------------------------------------------------------- |
| `install_nvim.sh` | Installs Neovim 0.11.7 and clones my Neovim configuration repository. |

More scripts will be added over time.

## Usage

You can either download and inspect a script before running it:

```bash
curl -fsSL https://adityagupta.dev/b/nvim -o install_nvim.sh
less install_nvim.sh
bash install_nvim.sh
```

Or run it directly:

```bash
curl -fsSL https://adityagupta.dev/b/nvim | bash
```

## What the Neovim Installer Does

The Neovim bootstrap script:

1. Detects the Linux distribution.
2. Installs required dependencies (`git`, `wget`, `tar`).
3. Checks whether Neovim 0.11.7 is already installed.
4. Prompts before installing or upgrading Neovim.
5. Installs the official Neovim binary to `/opt/nvim`.
6. Creates a symlink at `/usr/local/bin/nvim`.
7. Clones my Neovim configuration into `~/.config/nvim`.

Supported distributions:

* Arch Linux
* Debian / Ubuntu
* Fedora

## Philosophy

These scripts are designed for my own systems first.

That means they may make assumptions about:

* Preferred software choices
* Directory layouts
* Configuration locations
* Existing infrastructure

The scripts are intentionally straightforward Bash scripts that can be inspected and modified before execution.

## Repository Structure

```text
installers/
├── install_nvim.sh
└── ...
```

## Future Plans

Potential additions include:

* Fish shell setup
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
curl -fsSL https://adityagupta.dev/b/nvim
```

and review the contents before piping it into a shell.

## License

MIT
