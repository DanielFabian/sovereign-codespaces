# host-ssh-keys — DevContainer Feature

Bind-mount the host's `~/.ssh` into the container (read-only) so `git push`,
`ssh`, and friends Just Work from inside a devcontainer.

## When this makes sense

You're on a [sovereign-codespaces](https://github.com/DanielFabian/sovereign-codespaces)
devhost (or any host where your SSH key is acceptably trusted to the
container — see threat-model note below). The host's key is passphrase-less,
so an in-container ssh-agent socket would be ceremony without security gain;
a direct read-only bind of `~/.ssh` is the honest construction.

## Using it

```jsonc
{
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "ghcr.io/danielfabian/sovereign-codespaces/nix-via-host:latest": {},
    "ghcr.io/danielfabian/sovereign-codespaces/host-ssh-keys:latest": {}
  }
}
```

The mount uses `${localEnv:HOME}` so it resolves against whichever host
VS Code is currently connected to (devhost VM, WSL, plain Linux — all work).

## Threat-model note

This Feature is intended for **partner-mode** containers: open-ended,
trusted, root-ish shell access for you and your AI collaborator. Tool-mode
containers (locked-down, narrow toolset, untrusted code) should *not* use
this Feature — wire any push/publish capability in as an explicit,
reviewable tool instead.

## Read-only

The mount is `readonly`. The expected flow is: clone on host →
"Reopen in Container" → push from container. `known_hosts` is seeded by the
initial host-side clone, so no container-side writes are needed. If you
ever need to `ssh` to a brand-new host from inside the container, do it
once on the devhost first to seed `known_hosts`.
