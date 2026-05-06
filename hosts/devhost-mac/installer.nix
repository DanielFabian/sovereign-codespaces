# devhost-mac installer — thin wrapper over modules/devhost/installer.nix.
{
  ...
}:

{
  imports = [
    ../../modules/devhost/installer.nix
  ];

  devhost = {
    osDisk = "/dev/vda";
    workspaceDevice = "/dev/vdb";
    installer = {
      flakeUrl = "github:DanielFabian/sovereign-codespaces";
      hostAttr = "devhost-mac";
      authorizedKeys = (import ../../modules/devhost/authorized-keys.nix).keys;
    };
  };
}
