# Hyper-V Gen2 VM hardware configuration.
#
# Gen2 VMs are UEFI-only; disks appear via the hv_storvsc driver. Provision
# convention (set in your New-VM script): SCSI controller slot 0 = OS disk,
# slot 1 = workspace disk. We address them via /dev/disk/by-path so the
# config doesn't depend on the kernel's SCSI enumeration order — which has
# been observed to swap /dev/sda and /dev/sdb between boots / installs.
{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  # Hyper-V synthetic drivers.
  #   hv_storvsc — disks
  #   hv_netvsc  — network
  #   hv_utils   — KVP / time / vss integration with the host
  # The framebuffer (hyperv_drm; CONFIG_FB_HYPERV is unset upstream) is
  # autoloaded by udev once the vmbus probes; no need to list it here.
  boot.initrd.availableKernelModules = [
    "hv_storvsc"
    "hv_vmbus"
    "hv_netvsc"
  ];
  boot.kernelModules = [ "hv_utils" ];

  # Root fs - nixos-generators (format=hyperv) labels the single root
  # partition "nixos". Keep in sync with that format's expectations.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # Workspace disk. nofail so a missing sdb doesn't block boot (e.g. during
  # a rescue scenario). Labelled by devhost-init-workspace.service.
  fileSystems."/home" = {
    device = "/dev/disk/by-label/workspace";
    fsType = "ext4";
    options = [
      "nofail"
      "x-systemd.device-timeout=15s"
    ];
  };

  # Hyper-V provides time; don't fight it.
  services.timesyncd.enable = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
