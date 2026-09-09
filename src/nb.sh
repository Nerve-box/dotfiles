# ---------------------------------------------------------------------------
# Entry point
# 
# Source this file in your .bashrc
# ---------------------------------------------------------------------------

NB_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

source "$NB_DIR/lib/utils.sh"
source "$NB_DIR/lib/autoscale.sh"

export PATH="$PATH:$NB_DIR/bin"
