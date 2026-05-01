#!/usr/bin/env bash
# Bootstrap LSP + formatter for editing the flake. Deliberately minimal:
# this devcontainer is for *editing* sovereign-codespaces, not for using it.
# Production usage is via the nix-via-host Feature against an installed
# devhost, not via this container.
set -euo pipefail

echo "Installing nil (Nix LSP) and nixfmt..."
nix profile install nixpkgs#nil nixpkgs#nixfmt-rfc-style

echo "Verifying flake evaluates..."
nix eval --impure '.#nixosConfigurations.devhost-hyperv.config.system.build.toplevel.drvPath' >/dev/null
echo "Flake OK."

echo ""
echo "Dev environment ready. Useful commands:"
echo "  nix build .#packages.x86_64-linux.devhost-hyperv-iso"
echo "  nix build .#packages.aarch64-linux.devhost-mac-iso"
echo "  nix flake check"
