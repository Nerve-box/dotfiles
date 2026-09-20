KEYFILE="$HOME/.ssh/id_ed25519"

# Generate the key once, if missing
if [ ! -f "${KEYFILE}" ]; then
  ssh-keygen -q -t ed25519 -C "$(whoami)@$(hostname).arpa" -N "" -f "${KEYFILE}"
fi

# Reuse an existing agent if one is alive; otherwise start one
if ! ssh-add -l >/dev/null 2>&1; then
  if [ -z "${SSH_AUTH_SOCK:-}" ] || ! ssh-add -l >/dev/null 2>&1; then
    eval "$(ssh-agent -s)" >/dev/null
    ssh-add "${KEYFILE}"
  fi
fi
