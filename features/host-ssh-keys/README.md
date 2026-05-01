# host-ssh-keys — DevContainer Feature

Bind-mount the host's `~/.ssh` into the container so `git push`, `ssh`, and
friends Just Work from inside a devcontainer.

## When this makes sense

You're on a [sovereign-codespaces](https://github.com/DanielFabian/sovereign-codespaces)
devhost (or any host where your SSH key is acceptably trusted to the
container — see threat-model note below). The host's key is passphrase-less,
so an in-container ssh-agent socket would be ceremony without security gain;
a direct bind of `~/.ssh` is the honest construction.

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

The mount is read-write because the devcontainer Features spec doesn't
expose a `readonly` flag on `mounts` (the schema rejects it). In partner
mode this is consistent with the trust posture; in any stricter mode,
prefer agent-socket forwarding instead of this Feature.

