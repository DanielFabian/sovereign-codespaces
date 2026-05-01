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
    installer = {
      flakeUrl = "github:DanielFabian/sovereign-codespaces";
      hostAttr = "devhost-mac";
      # Apple Virtualization typically attaches the install ISO as another
      # virtio-blk device, not a SCSI cdrom; there is no /dev/sr0 to eject.
      # The operator detaches the ISO via the VM management tool instead.
      ejectDevice = null;
      authorizedKeys = (import ../../modules/devhost/authorized-keys.nix).keys;
    };
  };
}
