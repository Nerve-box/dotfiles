# ---------------------------------------------------------------------------
# Entry point
# 
# Source this file in your .bashrc
# ---------------------------------------------------------------------------

NB_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

source "$NB_DIR/install/git.sh"
source "$NB_DIR/install/github.sh"
source "$NB_DIR/install/node.sh"

source "$NB_DIR/lib/utils.sh"

export PATH="$PATH:$NB_DIR/bin"
