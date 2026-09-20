#!/bin/bash

# Load minimal profile
source "$NB_DIR/profiles/m.sh"

# Load node-specific scripts
source "$NB_DIR/install/git.sh"
source "$NB_DIR/install/build-essential.sh"
source "$NB_DIR/install/ssh-agent.sh"
