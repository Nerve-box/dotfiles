#!/bin/bash

proc_opts=$(findmnt -no OPTIONS /proc)

if [[ ! $proc_opts =~ hidepid=([124]|noaccess|invisible|ptraceable) ]]; then
    mount -o remount,hidepid=2 /proc
    grep -q '^proc /proc ' /etc/fstab || echo 'proc /proc proc defaults,hidepid=2 0 0' >> /etc/fstab
fi
