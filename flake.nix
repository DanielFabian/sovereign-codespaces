{
  description = "Sovereign codespaces — a self-hosted, cattle-not-pets NixOS dev-container host. Bring your own hardware (Hyper-V, Apple Virtualization), get a Codespaces-shaped workflow with none of the share-an-EPYC-and-pretend-it's-fast tax.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    {
      nixosConfigurations = {
        # x86_64 / Hyper-V — for Windows hosts running Hyper-V.
        devhost-hyperv = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [ ./hosts/devhost-hyperv ];
        };

        # aarch64 / Apple Virtualization — for Apple Silicon Macs.
        devhost-mac = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = { inherit inputs; };
          modules = [ ./hosts/devhost-mac ];
        };
      };

      # Installer ISOs. Built natively from nixpkgs' installation-cd-base —
      # no KVM required, builds fine in containers / WSL / on the target
      # platform itself. The auto-installer wipes the OS disk, runs
      # nixos-install --flake against this repo, and reboots.
      packages.x86_64-linux.devhost-hyperv-iso =
        (nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-base.nix"
            ./hosts/devhost-hyperv/installer.nix
          ];
        }).config.system.build.isoImage;

      packages.aarch64-linux.devhost-mac-iso =
        (nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-base.nix"
            ./hosts/devhost-mac/installer.nix
          ];
        }).config.system.build.isoImage;
    };
}
