#!/bin/bash
# Generate SSH host keys on first boot if they don't exist (persisted via volume)
if [ ! -f /etc/ssh/host_keys/ssh_host_ed25519_key ]; then
    ssh-keygen -t ed25519 -f /etc/ssh/host_keys/ssh_host_ed25519_key -N ""
    ssh-keygen -t rsa -b 4096 -f /etc/ssh/host_keys/ssh_host_rsa_key -N ""
fi

# Seed home directory from skeleton on first boot
if [ ! -f /home/dev/.zshrc ]; then
    cp -a /etc/skel.dev/. /home/dev/
    chown -R dev:dev /home/dev
fi

# Seed Pi and its packages independently for existing home volumes.
# Preserve any Pi configuration the user has already created.
if [ ! -f /home/dev/.pi/agent/settings.json ]; then
    mkdir -p /home/dev/.pi
    cp -a /etc/skel.dev/.pi/. /home/dev/.pi/
    chown -R dev:dev /home/dev/.pi
fi

exec /usr/sbin/sshd -D
