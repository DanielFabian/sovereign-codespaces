# sovereign-codespaces

A self-hosted, cattle-not-pets NixOS dev-container host. Bring your own
hardware; get a Codespaces-shaped workflow without sharing four EPYC cores
with strangers.

## What this is

Two things that fit together:

1. **A NixOS VM image** (`devhost-hyperv` for Windows/Hyper-V,
   `devhost-mac` for Apple Silicon) that boots into nothing but `sshd`,
   `docker`, and a Nix daemon. No desktop, no toolchains, no surprises.
2. **A devcontainer Feature** (`nix-via-host`) that, when added to a
   project's `.devcontainer/devcontainer.json`, bind-mounts the VM's
   `/nix/store` into the container and routes `nix` commands to the
   host's daemon. Result: zero-download container start-up, one shared
   store across every project, perfect store-path parity with the host.

The blast-radius story:

- Your laptop / workstation runs the hypervisor and nothing else of yours.
- The VM is cattle. SSH into it, `git clone`, "Reopen in Container", work.
- The container is the AI's playground. It can `rm -rf /` — the VM survives.
- The VM can be wiped and re-imaged in 5–10 minutes (`devhost-wipe`,
  insert ISO, power-cycle). `/home` lives on a second virtual disk and
  survives re-imaging.
- The host never has a toolchain on it. Nothing leaks out of the VM.

## Quick start

### Build an installer ISO

Any host with `nix` (and flakes enabled) can build an ISO. No KVM needed.

```bash
# x86_64 (Hyper-V): from any x86_64 Linux/WSL with /nix
nix build github:DanielFabian/sovereign-codespaces#devhost-hyperv-iso

# aarch64 (Apple Silicon): from an aarch64 Linux host or the Mac itself
nix build github:DanielFabian/sovereign-codespaces#devhost-mac-iso
```

### Provision the VM (Hyper-V example)

```powershell
New-VM -Generation 2 -Name devhost -MemoryStartupBytes 8GB
Set-VMFirmware -VMName devhost -EnableSecureBoot Off
New-VHD -Path os.vhdx        -Dynamic -SizeBytes 64GB
New-VHD -Path workspace.vhdx -Dynamic -SizeBytes 200GB
Add-VMHardDiskDrive -VMName devhost -Path os.vhdx
Add-VMHardDiskDrive -VMName devhost -Path workspace.vhdx
Add-VMDvdDrive      -VMName devhost -Path devhost.iso
Start-VM devhost
```

The ISO auto-partitions `/dev/sda`, runs `nixos-install`, reboots, and
prints a freshly-generated SSH pubkey via the MOTD on first login. Add it
to GitHub.

### Use it

```bash
ssh dany@<vm-ip>
git clone <your-repo>
cd <your-repo>
code .
# F1 → "Dev Containers: Reopen in Container"
```

In your project's `.devcontainer/devcontainer.json`:

```json
{
  "features": {
    "ghcr.io/danielfabian/sovereign-codespaces/nix-via-host:0": {}
  }
}
```

The Feature handles the `/nix` mount and daemon plumbing.

## Layout

```
flake.nix                          # one input: nixpkgs
hosts/
  devhost-hyperv/                  # x86_64 + Hyper-V
  devhost-mac/                     # aarch64 + Apple Virtualization
modules/
  docker.nix                       # docker + podman
  devhost/                         # cattle invariants shared by all variants
    default.nix                    #   sshd, user, nix, autoUpgrade, ...
    wipe.nix                       #   devhost-wipe command
    nix-share.nix                  #   /nix bind-mount target stable symlinks
    installer.nix                  #   parameterized auto-install module
    authorized-keys.nix            #   single source of truth for SSH keys
features/
  nix-via-host/                    # devcontainer Feature, published to ghcr.io
```

## Customizing for yourself

Fork, then change:

- `modules/devhost/authorized-keys.nix` — your SSH pubkeys
- `hosts/devhost-*/default.nix` — the `autoUpgradeFlake` reference
- `hosts/devhost-*/installer.nix` — the `flakeUrl`

Auto-upgrade points the VM at your fork; ISOs install from your fork.

## License

MIT — see [LICENSE](./LICENSE).
