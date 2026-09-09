# .nb dotfiles
**n**o **b**rainer dotfiles for homelabs

## What is it ?

Useful commands, tools and first-time setup for homelab containers

This is developed for debian/ubuntu distros


## The no-brainer setup

```
curl -sL https://github.com/Nerve-box/dotfiles/archive/refs/tags/0.0.1-alpha.zip -o /tmp/dotfiles.zip && unzip -o /tmp/dotfiles.zip -d /tmp/dotfiles-extract && mkdir -p ~/.nb && mv /tmp/dotfiles-extract/*/src/* ~/.nb/ && echo 'source ~/.nb/nb.sh' >> ~/.bashrc
```
Then refresh your terminal or `source ~/.bashrc`

## What it installs

- `git`
- `build-essential` (make, g++, gcc, dpkg-dev libc6-dev)
- `NVM`, `node`, `npm`
- Sets up an ssh key and adds it to the ssh-agent

## What tools it includes

- `nb_autoscale`
  - Interactive script that creates a set of systemd services to wrap a command that binds to a socket. It spawns up when traffic arrives, shuts down if there's no activity and offers reverse proxying (all within systemd, no 3rd party tools)
- `nb_autoscale_revert`
  - Interactive script that removes all autoscale systemd services for a command.
 
## License

Apache 2.0 - 2026 - Frederic Charette
