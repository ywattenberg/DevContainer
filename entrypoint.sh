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
if [ ! -f /home/dev/.pi/agent/settings.json ]; then
    mkdir -p /home/dev/.pi
    cp -a /etc/skel.dev/.pi/. /home/dev/.pi/
else
    # Add container defaults without replacing user-selected scalar settings.
    node <<'NODE'
const fs = require("node:fs");
const defaultsPath = "/etc/skel.dev/.pi/agent/settings.json";
const settingsPath = "/home/dev/.pi/agent/settings.json";
const defaults = JSON.parse(fs.readFileSync(defaultsPath, "utf8"));
const settings = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
const merged = { ...defaults, ...settings };

for (const key of ["packages", "extensions"]) {
    merged[key] = [...new Set([...(defaults[key] ?? []), ...(settings[key] ?? [])])];
}

fs.writeFileSync(settingsPath, `${JSON.stringify(merged, null, 2)}\n`);
NODE

    # Add new optional config files while preserving user-customized copies.
    if [ ! -f /home/dev/.pi/agent/btw.json ]; then
        install -D -o dev -g dev -m 0644 \
            /etc/skel.dev/.pi/agent/btw.json \
            /home/dev/.pi/agent/btw.json
    fi
    if [ ! -f /home/dev/.pi/agent/extensions/pi-model-status.ts ]; then
        install -D -o dev -g dev -m 0644 \
            /etc/skel.dev/.pi/agent/extensions/pi-model-status.ts \
            /home/dev/.pi/agent/extensions/pi-model-status.ts
    fi
fi
chown -R dev:dev /home/dev/.pi

exec /usr/sbin/sshd -D
