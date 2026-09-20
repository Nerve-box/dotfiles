if (( $(ulimit -Sn) < 65536 )); then
    cat > /etc/security/limits.d/99-nofile.conf <<'EOF'
* soft nofile 65536
* hard nofile 65536
root soft nofile 65536
root hard nofile 65536
EOF

    mkdir -p /etc/systemd/system.conf.d
    printf '[Manager]\nDefaultLimitNOFILE=65536\n' > /etc/systemd/system.conf.d/99-nofile.conf
fi
