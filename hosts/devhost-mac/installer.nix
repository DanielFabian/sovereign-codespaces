# devhost-mac installer — thin wrapper over modules/devhost/installer.nix.
{
  ...
}:

{
  imports = [
    ../../modules/devhost/installer.nix
  ];

  # The installer is a separate NixOS configuration from the installed
  # devhost. Give it the same serial-first console behavior so failures in
  # auto-install, DHCP, or stage-1 are visible in vfkit's serial.log.
  boot.initrd.availableKernelModules = [ "virtio_console" ];
  boot.initrd.kernelModules = [ "virtio_console" ];
  boot.kernelParams = [
    "console=tty0"
    "console=hvc0"
    "loglevel=7"
  ];

  devhost = {
    osDisk = "/dev/disk/by-path/pci-0000:00:06.0";
    workspaceDevice = "/dev/disk/by-path/pci-0000:00:07.0";
    partSep = "-part";
    installer = {
      flakeUrl = "github:DanielFabian/sovereign-codespaces";
      hostAttr = "devhost-mac";
      authorizedKeys = (import ../../modules/devhost/authorized-keys.nix).keys;
    };
  };
}
