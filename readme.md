# Bootstrap

A collection of bootstrap scripts for setting up tools and configurations I use across new machines, servers, and development environments.

The goal is simple: reduce the number of manual steps required after installing an operating system and make my setup reproducible.

## Available Scripts

| Script            | Description                                                           |
| ----------------- | --------------------------------------------------------------------- |
| `install_nvim.sh` | Installs Neovim 0.11.7 and clones my Neovim configuration repository. |
| `install_yazi.sh` | Installs Yazi terminal file manager and its dependencies.             |

More scripts will be added over time.

## Usage

To bootstrap a new machine and set up the `b` command tool, run the following:

```bash
curl -fsSL https://adityagupta.dev/b | bash
```

Once bootstrapped, you can run any installer script using the `b` command followed by its shortcut name:

```bash
b nvim
b yazi
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

## What the Yazi Installer Does

The Yazi bootstrap script:

1. Detects the Linux distribution.
2. Prompts before installing or upgrading Yazi.
3. Installs Yazi:
   * **Arch Linux**: Installs `yazi` via pacman.
   * **Debian / Ubuntu**: Downloads the latest `.deb` release package from GitHub and installs it.
   * **Fedora**: Enables the COPR repository (`lihaohong/yazi`) and installs `yazi` (initially skipping weak dependencies).
4. Subsequently installs the dependencies (`ffmpeg`, `7zip` / `p7zip-full`, `jq`, `poppler`, `fd` / `fd-find`, `ripgrep`, `fzf`, `zoxide`, `resvg`, `imagemagick`) to make Yazi available quicker.
5. Configures a shell wrapper function `y` in `~/.bashrc` and `~/.zshrc` that allows changing directory on exit.

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
.
├── bootstrap.sh
├── routes.sh
└── installers/
    ├── install_nvim.sh
    └── install_yazi.sh
```

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
