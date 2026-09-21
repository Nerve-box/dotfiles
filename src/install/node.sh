#!/bin/bash

if ! command -v node &> /dev/null; then
    # NVM is user-specific and not ideal for our use-case, we will rarely need multiple versions installed
    # wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh | PROFILE=$NB_DIR/install/pre.sh bash
    # export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
    # [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
    # nvm install --lts

    # Yuck...we need curl for this??
    apt-get install curl -y -qq 
    curl -fsSL https://deb.nodesource.com/setup_26.x -o nodesource_setup.sh
    sudo -E bash nodesource_setup.sh
    apt-get install nodejs -y -qq
fi
