# .nb dotfiles
**n**o **b**rainer dotfiles for homelabs

## What is it ?

Useful commands, tools and first-time setup for homelab containers

This is developed for debian/ubuntu distros

Tested in Proxmox VE 


## The no-brainer setup

```
wget -qO- https://raw.githubusercontent.com/Nerve-box/dotfiles/refs/heads/release/src/bin/nb_update | bash
```
Then refresh your terminal or `source ~/.bashrc` to perform initial setup.

## First launch

Choosing a profile (`$NB_PROFILE`) which applies configurations and installs software

- [M]inimal
  - `hidepid`: Enforces hidepid on non-root users
  - `ulimit`: Bumps ulimit to `65536`
  - `unprivileged`: Creates an unprivileged user `nb_{HOSTNAME}`

- [N]ode
  - `<Everything included in Minimal>`
  - `git`: Installs git
  - `node`: Installs NVM + Node + npm (latest LTS), adds a `.npmrc` config with good security defaults
  - `ssh-agent`: Sets up an ssh key for `{USER}@{HOSTNAME}.arpa` and adds it to the ssh-agent*

- [B]un
  - `<Everything included in Minimal>`
  - `git`: Installs git
  - `bun`: Installs Bun (latest LTS), adds a `bunfig.toml` config with good security defaults
  - `ssh-agent`: Sets up an ssh key for `{USER}@{HOSTNAME}.arpa` and adds it to the ssh-agent*

- [G]eneral
  - `<Everything included in Minimal>`
  - `git`: Installs git
  - `build-essential` (make, g++, gcc, dpkg-dev libc6-dev)
  - `ssh-agent`: Sets up an ssh key for `{USER}@{HOSTNAME}.arpa` and adds it to the ssh-agent*

- [Z]ero
  - (Nothing)


> Security notes:
> - Always prefer readonly Deploy keys assigned to a specific project, rather than root User SSH keys.
> - `nb_autoscale` systemd units use the unprivileged user created by nb scripts. You should always install apps inside "/home/nb_$HOSTNAME"


## What tools it includes

- `nb_autoscale`
  - Interactive script that creates a set of systemd services to wrap a command that binds to a socket. It spawns up when traffic arrives, shuts down if there's no activity and offers reverse proxying (all within systemd, no 3rd party tools)
- `nb_autoscale_revert`
  - Interactive script that removes all autoscale systemd services for a command.
- `nb_update`
  - Installs or updates the local nb scripts
- `nb_uninstall`
  - Uninstalls the local nb scripts


## Exported variables

- `NB_DIR`: NB script directory
- `NB_PROFILE`: Currently loaded profile
- `NB_VERSION`: Current NB scripts version
- `NB_USER`: Unprivileged user created by NB scripts

## License

Apache 2.0 - 2026 - Frederic Charette
