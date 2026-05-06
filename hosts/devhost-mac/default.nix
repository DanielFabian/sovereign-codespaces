# devhost-mac — disposable NixOS dev-container host for Apple Virtualization
# on Apple Silicon (aarch64). Counterpart to devhost-hyperv.
#
# Substrate-specific bits only; cattle invariants live in
# modules/devhost/default.nix.
{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/devhost
  ];

  devhost = {
    autoUpgradeFlake = "github:DanielFabian/sovereign-codespaces#devhost-mac";
    # Stable by-path identifiers. Kernel-assigned vd[abc] ordering is not
    # stable across boots under vfkit (same lesson learned on Hyper-V); PCI
    # topology is. The mapping below is the empirical assignment vfkit gives
    # the launcher's CLI order: OS first, workspace second, ISO third —
    # PCI slots 06, 07, 05 respectively. If you reorder devices in
    # mac/devhost-mac.sh, update these accordingly.
    osDisk = "/dev/disk/by-path/pci-0000:00:06.0";
    workspaceDevice = "/dev/disk/by-path/pci-0000:00:07.0";
    partSep = "-part";
    git = {
      userName = "Daniel Fabian";
      userEmail = "daniel.fabian@integral-it.ch";
    };
  };

  # Swapfile rationale on this variant differs from Hyper-V: Apple
  # Virtualization assigns fixed RAM at VM-create time (no balloon driver),
  # so swap is not a "pressure beacon" — it's just OOM ergonomics. Agentic
  # tools have a demonstrated bias toward filling RAM (duplicate processes,
  # /tmp, leaked workers); without swap that becomes a hard OOM-kill that
  # nukes ssh sessions before you can react. With swap it becomes thrash you
  # can notice. 8 GiB on a regenerable VM disk is rounding error.
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 8 * 1024; # MiB
    }
  ];
}
