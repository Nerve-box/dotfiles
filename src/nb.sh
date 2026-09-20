#!/bin/bash

# Entry point
# Source this file in your .bashrc

NB_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

source "$NB_DIR/lib/utils.sh"

# BASH PROFILE updates
source "$NB_DIR/install/pre.sh"

# Check NB_PROFILE
if [[ -z "${NB_PROFILE:-}" ]]; then
    ask_choice NB_PROFILE "Select profile (m)inimal, (n)ode, (b)un, (g)eneral, (z)ero" "mnbgz"
    export NB_PROFILE
    echo "export NB_PROFILE=$NB_PROFILE" >> $NB_DIR/install/pre.sh
fi

# Load profile
source "$NB_DIR/profiles/$NB_PROFILE.sh"

# Export cmd tools
export PATH="$PATH:$NB_DIR/bin"
