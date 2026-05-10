#!/bin/sh
# host-ssh-keys: write the symlink helper that postCreateCommand will
# invoke at container start. Image build time has no $HOME for the
# eventual remoteUser, so we defer the symlink to runtime.
set -eu

install -d -m 0755 /usr/local/sbin
cat > /usr/local/sbin/host-ssh-keys-link <<'EOF'
#!/bin/sh
# Symlink $HOME/.ssh to /run/host-ssh (the bind mount of the host's
# ~/.ssh). Idempotent: replaces an existing symlink, but never silently
# clobbers a real .ssh directory with content the user might want.
set -eu

src=/run/host-ssh
dst="${HOME}/.ssh"

if [ ! -d "$src" ]; then
    echo "host-ssh-keys: $src not present (mount missing?); skipping symlink." >&2
    exit 0
fi

if [ -L "$dst" ]; then
    # Existing symlink — replace unconditionally.
    ln -sfn "$src" "$dst"
    exit 0
fi

if [ -d "$dst" ]; then
    # Real directory. Refuse to clobber if it contains anything other
    # than the auto-generated known_hosts that base images often write.
    n=$(find "$dst" -mindepth 1 -maxdepth 1 ! -name 'known_hosts' ! -name 'known_hosts.old' | wc -l)
    if [ "$n" -gt 0 ]; then
        echo "host-ssh-keys: $dst contains files other than known_hosts; refusing to replace with symlink." >&2
        echo "host-ssh-keys: move $dst aside and re-run /usr/local/sbin/host-ssh-keys-link." >&2
        exit 1
    fi
    rm -rf "$dst"
fi

ln -sfn "$src" "$dst"
EOF
chmod 0755 /usr/local/sbin/host-ssh-keys-link

echo "host-ssh-keys: installed symlink helper at /usr/local/sbin/host-ssh-keys-link"
