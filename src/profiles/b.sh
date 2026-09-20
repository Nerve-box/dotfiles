#!/bin/bash

# Load minimal profile
source "$NB_DIR/profiles/m.sh"

# Load bun-specific scripts
source "$NB_DIR/install/git.sh"
source "$NB_DIR/install/bun.sh"
source "$NB_DIR/install/ssh-agent.sh"
