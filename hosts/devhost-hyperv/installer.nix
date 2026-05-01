# devhost-hyperv installer — thin wrapper over modules/devhost/installer.nix.
{
  ...
}:

{
  imports = [
    ../../modules/devhost/installer.nix
  ];

  devhost = {
    # Slot 0 on the SCSI controller. See hosts/devhost-hyperv/default.nix.
    osDisk = "/dev/disk/by-path/acpi-MSFT1000:00-scsi-0:0:0:0";
    workspaceDevice = "/dev/disk/by-path/acpi-MSFT1000:00-scsi-0:0:0:1";
    partSep = "-part";
    installer = {
      flakeUrl = "github:DanielFabian/sovereign-codespaces";
      hostAttr = "devhost-hyperv";
      ejectDevice = "/dev/sr0"; # Hyper-V exposes attached ISO as SCSI cdrom
      # SSH pubkeys allowed into the *installer environment* (debug only).
      authorizedKeys = (import ../../modules/devhost/authorized-keys.nix).keys;
    };
  };
}
