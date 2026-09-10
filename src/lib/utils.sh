# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log()  { echo -e "\033[0;32m[*]\033[0m $*"; }
export -f log
warn()  { echo -e "\033[1;33m[!]\033[0m $*"; }
export -f warn
error() { echo -e "\033[0;31m[x]\033[0m $*" >&2; }
export -f error
die()   { error "$*"; exit 1; }
export -f die

# Read a line from the real terminal (from tty or input)
ask() {
    local prompt="$1"
    local __resultvar="$2"
    local reply
    if [ ! -r /dev/tty ]; then
        die "No interactive terminal available (/dev/tty not readable). Cannot prompt for input."
    fi
    read -r -p "$prompt" reply < /dev/tty
    printf -v "$__resultvar" '%s' "$reply"
}
export -f ask
