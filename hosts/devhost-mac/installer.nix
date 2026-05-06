# devhost-mac installer — thin wrapper over modules/devhost/installer.nix.
{
  ...
}:

{
  imports = [
    ../../modules/devhost/installer.nix
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
