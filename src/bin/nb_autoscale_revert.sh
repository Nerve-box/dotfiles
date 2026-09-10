#!/bin/bash
# ---------------------------------------------------------------------------
# Reverts autoscale setup
# ---------------------------------------------------------------------------

set -euo pipefail

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
