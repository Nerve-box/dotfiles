
if ! command -v node &> /dev/null; then
    wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh | bash
    export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
    nvm install --lts
fi
