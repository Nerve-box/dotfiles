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

# Multiple choice
ask_choice() {
    local __resultvar="$1" __prompt="$2" __options="$3" __initial="${4:-}"
    local __lc_options="${__options,,}"
    local __value="${__initial,,}"
    local __answer   # not "reply": ask() has a local of that name that would shadow it
 
    if [[ ${#__value} -eq 1 && "$__lc_options" == *"$__value"* ]]; then
        printf -v "$__resultvar" '%s' "$__value"
        return
    fi
 
    [[ -n "$__initial" ]] && echo "Invalid value: '$__initial'" >&2
 
    while true; do
        ask "$__prompt [$__options]: " __answer
        __answer="${__answer,,}"
        if [[ ${#__answer} -eq 1 && "$__lc_options" == *"$__answer"* ]]; then
            printf -v "$__resultvar" '%s' "$__answer"
            return
        fi
        echo "Please enter exactly one of: $__options" >&2
    done
}
export -f ask_choice
