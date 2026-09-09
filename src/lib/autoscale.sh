nb_autoscale() {

  # ---------------------------------------------------------------------------
  # Step 1: System checks
  # ---------------------------------------------------------------------------

  info "Running system compatibility checks..."

  if ! command -v systemctl >/dev/null 2>&1 || [ ! -d /run/systemd/system ]; then
    die "This system does not appear to be running systemd. Aborting."
  fi

  SOCKET_PROXYD=""
  for candidate in /lib/systemd/systemd-socket-proxyd /usr/lib/systemd/systemd-socket-proxyd; do
    if [ -x "$candidate" ]; then
      SOCKET_PROXYD="$candidate"
      break
    fi
  done
  if [ -z "$SOCKET_PROXYD" ]; then
    die "systemd-socket-proxyd not found. It ships with systemd but is missing on this system."
  fi

  if ! command -v ss >/dev/null 2>&1; then
    warn "'ss' command not found; the idle monitor script requires it. Attempting to continue, but install iproute2 if the monitor fails."
  fi

  local script_dir
  script_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
  local MONITOR_SCRIPT="${script_dir}/../run/nb-monitor.sh"

  if [ ! -f "$MONITOR_SCRIPT" ]; then
    die "Monitor script not found at ${MONITOR_SCRIPT}."
  fi

  # ---------------------------------------------------------------------------
  # Step 2: Prompt for and validate inputs
  # ---------------------------------------------------------------------------

  NAME=""
  PUBLIC_PORT=""
  INTERNAL_PORT=""
  START_CMD=""

  validate_name() {
    local n="$1"
    if [ -z "$n" ]; then
      error "Name cannot be empty."
      return 1
    fi
    if [[ "$n" == *.service ]]; then
      error "Do not include '.service' — it will be added automatically."
      return 1
    fi
    if [[ ! "$n" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      error "Name may only contain letters, numbers, hyphens and underscores (no spaces or other special characters)."
      return 1
    fi
    return 0
  }

  validate_port() {
    local p="$1"
    if [[ ! "$p" =~ ^[0-9]+$ ]]; then
      error "Port must be a number."
      return 1
    fi
    if [ "$p" -lt 1 ] || [ "$p" -gt 65535 ]; then
      error "Port must be between 1 and 65535."
      return 1
    fi
    return 0
  }

  while true; do
    ask "Enter a name for the service (letters, numbers, - and _ only): " NAME
    validate_name "$NAME" && break
  done

  SYSTEMD_DIR="/etc/systemd/system"

  # ---------------------------------------------------------------------------
  # Step 2b: Detect an existing install
  # ---------------------------------------------------------------------------

  EXISTING_ARTIFACTS=(
  "${SYSTEMD_DIR}/${NAME}.service"
  "${SYSTEMD_DIR}/${NAME}-proxy.service"
  "${SYSTEMD_DIR}/${NAME}-proxy.socket"
  "${SYSTEMD_DIR}/${NAME}-monitor.service"
  )

  FOUND_EXISTING=false
  for f in "${EXISTING_ARTIFACTS[@]}"; do
    if [ -e "$f" ]; then
      FOUND_EXISTING=true
      break
    fi
  done

  OLD_INTERNAL_PORT=""
  OLD_FIREWALL_TOOL=""

  if [ "$FOUND_EXISTING" = true ]; then
    warn "An existing install named '${NAME}' was detected (some or all of its files/units already exist)."
    ask "Continue and overwrite/reconfigure it? [y/N]: " CONFIRM
    [[ "$CONFIRM" =~ ^[Yy]$ ]] || die "Aborted by user."
  fi

  while true; do
    ask "Enter the PUBLIC port to listen on (what clients connect to): " PUBLIC_PORT
    validate_port "$PUBLIC_PORT" && break
  done

  while true; do
    ask "Enter the INTERNAL port your app will listen on: " INTERNAL_PORT
    if ! validate_port "$INTERNAL_PORT"; then
      continue
    fi
    if [ "$INTERNAL_PORT" = "$PUBLIC_PORT" ]; then
      error "Internal port must be different from the public port."
      continue
    fi
    break
  done

  while true; do
    ask "Enter the start command for your application (no shell pipes/&&/redirects unless wrapped in 'sh -c ...'): " START_CMD
    if [ -z "$START_CMD" ]; then
      error "Start command cannot be empty."
      continue
    fi
    break
  done

  info "Configuration:"
  echo "    Name:          $NAME"
  echo "    Public port:   $PUBLIC_PORT"
  echo "    Internal port: $INTERNAL_PORT"
  echo "    Start command: $START_CMD"
  ask "Proceed with this configuration? [y/N]: " CONFIRM
  [[ "$CONFIRM" =~ ^[Yy]$ ]] || die "Aborted by user."

  # ---------------------------------------------------------------------------
  # Step 3: If reconfiguring, fully quiesce the old install first.
  # ---------------------------------------------------------------------------

  if [ "$FOUND_EXISTING" = true ]; then
    info "Stopping existing units before reconfiguring..."
    systemctl stop "${NAME}-monitor.service" 2>/dev/null || true
    systemctl stop "${NAME}-proxy.socket" 2>/dev/null || true
    systemctl stop "${NAME}-proxy.service" 2>/dev/null || true
    systemctl stop "${NAME}.service" 2>/dev/null || true
    systemctl disable "${NAME}-monitor.service" 2>/dev/null || true
    systemctl disable "${NAME}-proxy.socket" 2>/dev/null || true
    systemctl disable "${NAME}.service" 2>/dev/null || true
  fi

  # ---------------------------------------------------------------------------
  # Step 4: Clean up old firewall rules if the internal port is changing
  # ---------------------------------------------------------------------------

  if [ -n "$OLD_INTERNAL_PORT" ] && [ "$OLD_INTERNAL_PORT" != "$INTERNAL_PORT" ]; then
    info "Internal port changed (${OLD_INTERNAL_PORT} -> ${INTERNAL_PORT}); removing old firewall rules for ${OLD_INTERNAL_PORT}..."
    case "$OLD_FIREWALL_TOOL" in
      ufw)
        ufw delete allow in on lo to any port "${OLD_INTERNAL_PORT}" proto tcp 2>/dev/null || true
        ufw delete deny in to any port "${OLD_INTERNAL_PORT}" proto tcp 2>/dev/null || true
      ;;
      firewalld)
        firewall-cmd --permanent --remove-rich-rule="rule family='ipv4' source address='127.0.0.1' port port='${OLD_INTERNAL_PORT}' protocol='tcp' accept" 2>/dev/null || true
        firewall-cmd --permanent --remove-rich-rule="rule priority='32767' family='ipv4' port port='${OLD_INTERNAL_PORT}' protocol='tcp' reject" 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
      ;;
      iptables)
        iptables -D INPUT -p tcp --dport "${OLD_INTERNAL_PORT}" ! -i lo -j DROP 2>/dev/null || true
      ;;
      "")
        : # no record of a previous firewall tool; nothing to clean up
      ;;
      *)
        warn "Unrecognized previous firewall tool '${OLD_FIREWALL_TOOL}' in state file; skipping automatic cleanup."
      ;;
    esac
  fi

  # ---------------------------------------------------------------------------
  # Step 5: Main application service
  # ---------------------------------------------------------------------------

  # systemd treats a bare '%' in unit file values as the start of a specifier
  # (e.g. %h, %i). Escape any literal '%' the user typed so it isn't
  # misinterpreted or rejected by the unit parser.
  START_CMD_ESCAPED="${START_CMD//%/%%}"

  info "Creating ${NAME}.service..."
  cat > "${SYSTEMD_DIR}/${NAME}.service" <<EOF
[Unit]
Description=${NAME} service
BindsTo=${NAME}-proxy.socket
After=${NAME}-proxy.socket

[Service]
ExecStart=${START_CMD_ESCAPED}
Restart=on-failure
RestartSec=3s
EOF

  # ---------------------------------------------------------------------------
  # Step 6: Socket unit
  # ---------------------------------------------------------------------------

  info "Creating ${NAME}-proxy.socket..."
  cat > "${SYSTEMD_DIR}/${NAME}-proxy.socket" <<EOF
[Unit]
Description=${NAME} Socket Activation

[Socket]
ListenStream=${PUBLIC_PORT}

[Install]
WantedBy=sockets.target
EOF

  # ---------------------------------------------------------------------------
  # Step 7: Proxy service
  # ---------------------------------------------------------------------------

  info "Creating ${NAME}-proxy.service..."
  cat > "${SYSTEMD_DIR}/${NAME}-proxy.service" <<EOF
[Unit]
Description=${NAME} Socket Proxy
Requires=${NAME}.service
After=${NAME}.service

[Service]
# Starting the app process does not mean it is listening yet.
# Wait (up to ~30s) until the backend actually accepts connections
# before handing traffic to it, to avoid dropping the client's
# already-accepted connection (seen as ECONNRESET on the client).
ExecStartPre=/bin/bash -c 'for i in \$(seq 1 150); do (echo > /dev/tcp/127.0.0.1/${INTERNAL_PORT}) >/dev/null 2>&1 && exit 0; sleep 0.2; done; echo "${NAME}: backend on port ${INTERNAL_PORT} did not become ready in time" >&2; exit 1'
ExecStart=${SOCKET_PROXYD} 0.0.0.0:${INTERNAL_PORT}
EOF

  # ---------------------------------------------------------------------------
  # Step 8: Monitor service
  # ---------------------------------------------------------------------------

  info "Creating ${NAME}-monitor.service..."
  cat > "${SYSTEMD_DIR}/${NAME}-monitor.service" <<EOF
[Unit]
Description=Network Idle Monitor for ${NAME}
After=network.target

[Service]
Type=simple
ExecStart=${MONITOR_SCRIPT} ${PUBLIC_PORT} ${NAME}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  # ---------------------------------------------------------------------------
  # Step 10: Firewall — configure BEFORE starting anything, so the internal
  # port is never briefly reachable from outside during first-time setup.
  # ---------------------------------------------------------------------------

  info "Configuring firewall to block external access to internal port ${INTERNAL_PORT}..."
  FIREWALL_CONFIGURED=false
  FIREWALL_TOOL=""

  if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    # Explicitly allow loopback first (ufw's "deny" is not interface-scoped
    # by default and would otherwise also block the proxy's local connection
    # to the app), then deny everything else on that port.
    ufw allow in on lo to any port "${INTERNAL_PORT}" proto tcp comment "${NAME}: allow local proxy traffic" || true
    ufw deny in to any port "${INTERNAL_PORT}" proto tcp comment "${NAME}: block external access to internal port" || true
    FIREWALL_CONFIGURED=true
    FIREWALL_TOOL="ufw"
    info "ufw rules added: allow loopback, deny external traffic to tcp/${INTERNAL_PORT}."
  elif command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
    # Accept rule for loopback runs at default priority (0); reject rule is
    # given a lower-precedence (higher-numbered) priority so it's evaluated
    # after, ensuring local proxy traffic isn't rejected.
    firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='127.0.0.1' port port='${INTERNAL_PORT}' protocol='tcp' accept" || true
    firewall-cmd --permanent --add-rich-rule="rule priority='32767' family='ipv4' port port='${INTERNAL_PORT}' protocol='tcp' reject" || true
    firewall-cmd --reload || true
    FIREWALL_CONFIGURED=true
    FIREWALL_TOOL="firewalld"
    info "firewalld rules added: allow loopback, reject external traffic to tcp/${INTERNAL_PORT}."
  elif command -v iptables >/dev/null 2>&1; then
    iptables -C INPUT -p tcp --dport "${INTERNAL_PORT}" ! -i lo -j DROP 2>/dev/null || \
      iptables -I INPUT -p tcp --dport "${INTERNAL_PORT}" ! -i lo -j DROP
    FIREWALL_CONFIGURED=true
    FIREWALL_TOOL="iptables"
    info "iptables rule added: drop non-loopback traffic to tcp/${INTERNAL_PORT}."
    warn "iptables rules are not persistent across reboots by default. Consider installing iptables-persistent or netfilter-persistent."
  fi

  if [ "$FIREWALL_CONFIGURED" = false ]; then
    warn "No supported firewall tool (ufw/firewalld/iptables) was found or active. Internal port ${INTERNAL_PORT} was NOT firewalled — please secure it manually."
  fi

  # ---------------------------------------------------------------------------
  # Step 11: reload, enable/(re)start
  # ---------------------------------------------------------------------------

  info "Reloading systemd daemon..."
  systemctl daemon-reload

  info "Enabling ${NAME}-proxy.socket, ${NAME}.service and ${NAME}-monitor.service..."
  systemctl enable --now "${NAME}-proxy.socket"
  systemctl enable "${NAME}.service"
  systemctl enable --now "${NAME}-monitor.service"

  echo
  info "Done! Summary:"
  echo "    Public endpoint:  0.0.0.0:${PUBLIC_PORT}  (socket-activated)"
  echo "    Internal target:  0.0.0.0:${INTERNAL_PORT} (firewalled from outside)"
  echo "    Service:          ${NAME}.service"
  echo "    Proxy:            ${NAME}-proxy.service / ${NAME}-proxy.socket"
  echo "    Idle monitor:     ${NAME}-monitor.service (stops the service after 360s of no connections)"
  echo
  echo "    Check status with: systemctl status ${NAME}.service ${NAME}-proxy.socket ${NAME}-monitor.service"
}

nb_revert_autoscale() {
    local name="$1"
    [ -z "$name" ] && die "Usage: nb_revert_autoscale <service-name>"
    [ "$EUID" -ne 0 ] && die "This must be run as root."

    local systemd_dir="/etc/systemd/system"
    local svc="${name}.service"
    local proxy_svc="${name}-proxy.service"
    local proxy_sock="${name}-proxy.socket"
    local mon_svc="${name}-monitor.service"

    # -----------------------------------------------------------------
    # Derive the internal port live — it's only needed for firewall
    # cleanup, and only exists as long as the proxy unit does. Fall
    # back to the ufw comment tag if the unit's already gone (e.g. a
    # resumed/partial revert), then ask as a last resort.
    # -----------------------------------------------------------------

    local internal_port=""
    if [ -f "${systemd_dir}/${proxy_svc}" ]; then
        internal_port="$(grep -oP 'systemd-socket-proxyd\s+\S+:\K[0-9]+' "${systemd_dir}/${proxy_svc}" 2>/dev/null || true)"
    fi
    if [ -z "$internal_port" ]; then
        internal_port="$(ufw status numbered 2>/dev/null | grep "${name}:" | grep -oP '^\[\s*\d+\]\s+\K[0-9]+' | head -n1 || true)"
    fi
    if [ -z "$internal_port" ] && [ ! -f "${systemd_dir}/${svc}" ] && [ ! -f "${systemd_dir}/${proxy_sock}" ]; then
        die "Nothing found for '${name}' — already reverted, or never set up."
    fi
    if [ -z "$internal_port" ]; then
        warn "Could not determine the internal port automatically."
        ask "Enter it to clean up firewall rules, or leave blank to skip: " internal_port
    fi

    info "Reverting '${name}' (internal port: ${internal_port:-unknown})..."
    ask "Proceed? [y/N]: " CONFIRM
    [[ "$CONFIRM" =~ ^[Yy]$ ]] || die "Aborted by user."

    # -----------------------------------------------------------------
    # Stop/disable unconditionally. systemctl already treats "stop an
    # inactive unit" and "disable an already-disabled unit" as no-ops,
    # so there's nothing to pre-check — just do it and ignore errors
    # for units that were never there.
    # -----------------------------------------------------------------

    systemctl stop "$mon_svc" "$proxy_sock" "$proxy_svc" "$svc" 2>/dev/null || true
    systemctl disable "$mon_svc" "$proxy_sock" "$svc" 2>/dev/null || true

    # -----------------------------------------------------------------
    # ufw only — same reasoning, `delete` on an absent rule just fails
    # quietly, so no existence check needed first.
    # -----------------------------------------------------------------

    if [ -n "$internal_port" ]; then
        ufw delete allow in on lo to any port "${internal_port}" proto tcp 2>/dev/null || true
        ufw delete deny in to any port "${internal_port}" proto tcp 2>/dev/null || true
    fi

    rm -f "${systemd_dir}/${svc}" "${systemd_dir}/${proxy_svc}" "${systemd_dir}/${proxy_sock}" "${systemd_dir}/${mon_svc}"
    systemctl daemon-reload
    systemctl reset-failed 2>/dev/null || true

    info "Done. '${name}' reverted."
}
