#!/usr/bin/env bash
# devhost-mac — host-side launcher for the aarch64 NixOS devhost on Apple
# Silicon. Thin wrapper around vfkit (Apple's Virtualization.framework via a
# tidy Go CLI). State lives entirely under $STATE_DIR; remove the dir and
# the VM is gone — cattle, all the way down to the host.
#
# Subcommands:
#   create   — allocate two raw disk images, expect an ISO at $STATE_DIR/iso
#   up       — boot vfkit (foreground); HDD has higher boot priority than ISO
#   destroy  — rm -rf the state dir (with confirm)
#   status   — show state dir contents and disk sizes
#   ssh      — discover VM IP and exec ssh into it
#
# ISO acquisition is deliberately manual: download the latest devhost-mac.iso
# from the GitHub Releases page into $STATE_DIR/iso. The guest auto-upgrades
# from the flake nightly anyway, so a stale ISO only matters at re-install.
set -euo pipefail

STATE_DIR="${DEVHOST_MAC_STATE:-$HOME/.local/share/devhost-mac}"
OS_DISK="$STATE_DIR/os.img"
WS_DISK="$STATE_DIR/workspace.img"
ISO_PATH="$STATE_DIR/iso"     # expect: $STATE_DIR/iso/devhost-mac.iso
EFI_STORE="$STATE_DIR/efi-vars"

# Sizing — generous defaults; cattle disks, easy to recreate.
OS_DISK_SIZE="${DEVHOST_MAC_OS_SIZE:-40G}"
WS_DISK_SIZE="${DEVHOST_MAC_WS_SIZE:-200G}"
VCPUS="${DEVHOST_MAC_VCPUS:-8}"
MEMORY_MIB="${DEVHOST_MAC_MEMORY:-16384}"
SSH_USER="${DEVHOST_MAC_SSH_USER:-dany}"

die() { echo "devhost-mac: $*" >&2; exit 1; }
log() { echo "devhost-mac: $*" >&2; }

cmd_create() {
  mkdir -p "$STATE_DIR" "$ISO_PATH"
  if [[ -e "$OS_DISK" || -e "$WS_DISK" ]]; then
    die "disks already exist at $STATE_DIR; run 'destroy' first"
  fi
  # macOS mkfile creates sparse files quickly. Truncate works too and is
  # more portable, but mkfile is the macOS-native idiom.
  if command -v mkfile >/dev/null 2>&1; then
    mkfile -n "$OS_DISK_SIZE" "$OS_DISK"
    mkfile -n "$WS_DISK_SIZE" "$WS_DISK"
  else
    truncate -s "$OS_DISK_SIZE" "$OS_DISK"
    truncate -s "$WS_DISK_SIZE" "$WS_DISK"
  fi
  log "created $OS_DISK ($OS_DISK_SIZE) and $WS_DISK ($WS_DISK_SIZE)"
  log "place the installer ISO at: $ISO_PATH/devhost-mac.iso"
  log "  e.g.: gh release download v0.1.0 --repo DanielFabian/sovereign-codespaces -p devhost-mac.iso -O $ISO_PATH/devhost-mac.iso"
  log "then: devhost-mac up"
}

cmd_up() {
  local gui=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --gui) gui=1; shift ;;
      *) die "unknown 'up' arg: $1" ;;
    esac
  done
  [[ -e "$OS_DISK" ]]    || die "no os disk; run 'create' first"
  [[ -e "$WS_DISK" ]]    || die "no workspace disk; run 'create' first"
  local iso
  iso="$(find "$ISO_PATH" -maxdepth 1 -name '*.iso' -print -quit 2>/dev/null || true)"
  [[ -n "${iso:-}" ]] || die "no ISO under $ISO_PATH; download devhost-mac.iso from a release"

  # vfkit's EFI bootloader needs a writable variable store on first run.
  if [[ ! -e "$EFI_STORE" ]]; then
    log "initializing EFI variable store"
    : > "$EFI_STORE"
  fi

  # NOTE: vfkit CLI flags below are written from documentation, not from
  # firsthand verification on this dev container (no Mac here). Specifically
  # uncertain:
  #   - exact spelling of boot-priority attribute on virtio-blk devices
  #     (vfkit accepts a comma-keyed device spec; "deviceId" / "bootIndex"
  #     attribute name has changed across vfkit versions)
  #   - whether the vmnet NAT mode auto-leases an IP without explicit
  #     "vmnet-shared" subtype
  # First-run iteration on the Mac will resolve these; the structure is right.
  log "booting devhost-mac (vfkit, NAT networking, ISO attached for re-install)"
  local gui_args=()
  if (( gui )); then
    log "  with GUI window"
    # vfkit's --gui only opens a window if we also wire up a GPU and input
    # devices. Without these the flag is silently a no-op.
    gui_args=(
      --gui
      --device "virtio-gpu"
      --device "virtio-input,keyboard"
      --device "virtio-input,pointing"
    )
  fi
  exec vfkit \
    "${gui_args[@]}" \
    --cpus "$VCPUS" \
    --memory "$MEMORY_MIB" \
    --bootloader "efi,variable-store=$EFI_STORE,create" \
    --device "virtio-blk,path=$OS_DISK" \
    --device "virtio-blk,path=$WS_DISK" \
    --device "virtio-blk,path=$iso,readonly" \
    --device "virtio-net,nat,mac=72:20:43:00:00:01" \
    --device "virtio-rng" \
    --device "virtio-serial,logFilePath=$STATE_DIR/serial.log"
  # Boot priority: vfkit boots virtio-blk devices in CLI order by default,
  # so OS disk first, ISO last → normal boots hit the HDD instantly,
  # post-wipe boots fall through to the ISO and auto-install runs.
  # If that proves wrong on first run, we add an explicit boot-priority
  # attribute to the ISO device.
}

cmd_destroy() {
  [[ -d "$STATE_DIR" ]] || die "no state dir at $STATE_DIR"
  read -r -p "Destroy $STATE_DIR (disks + EFI vars + ISO)? type 'destroy': " confirm
  [[ "$confirm" == "destroy" ]] || die "aborted"
  rm -rf "$STATE_DIR"
  log "destroyed $STATE_DIR"
}

cmd_status() {
  if [[ ! -d "$STATE_DIR" ]]; then
    echo "no state at $STATE_DIR"
    return
  fi
  echo "state dir: $STATE_DIR"
  ls -lh "$STATE_DIR" 2>/dev/null || true
  if [[ -d "$ISO_PATH" ]]; then
    echo "iso dir:"
    ls -lh "$ISO_PATH" 2>/dev/null || true
  fi
}

cmd_ssh() {
  # Discover the VM's IP by matching the MAC we set in cmd_up against
  # macOS's DHCP lease file. Apple's vmnet NAT subnet is 192.168.64.0/24.
  local mac="72:20:43:00:00:01"
  local lease_file="/var/db/dhcpd_leases"
  [[ -r "$lease_file" ]] || die "cannot read $lease_file (vmnet NAT leases live here)"
  local ip
  ip="$(awk -v mac="$mac" '
    BEGIN{IGNORECASE=1}
    /^{/{rec=""}
    {rec=rec"\n"$0}
    /^}/{
      if (rec ~ ("hw_address=1," mac) || rec ~ ("hw_address=" mac)) {
        match(rec, /ip_address=([0-9.]+)/, m); print m[1]; exit
      }
    }' "$lease_file")"
  [[ -n "$ip" ]] || die "no DHCP lease found for $mac yet; is the VM booted?"
  log "devhost-mac IP: $ip"
  exec ssh "$SSH_USER@$ip" "$@"
}

case "${1:-}" in
  create)  shift; cmd_create  "$@" ;;
  up)      shift; cmd_up      "$@" ;;
  destroy) shift; cmd_destroy "$@" ;;
  status)  shift; cmd_status  "$@" ;;
  ssh)     shift; cmd_ssh     "$@" ;;
  ""|-h|--help|help)
    cat <<EOF
devhost-mac — host-side launcher for the aarch64 NixOS devhost.

Usage:
  devhost-mac create     allocate disks, prepare state dir
  devhost-mac up [--gui]    boot the VM (foreground; --gui opens a window)
  devhost-mac ssh [...]  discover IP via DHCP lease, exec ssh
  devhost-mac status     show state dir contents
  devhost-mac destroy    rm -rf state dir (confirm required)

State dir: $STATE_DIR
Override sizing via DEVHOST_MAC_OS_SIZE / DEVHOST_MAC_WS_SIZE / DEVHOST_MAC_VCPUS / DEVHOST_MAC_MEMORY.

Place the installer ISO at \$STATE_DIR/iso/devhost-mac.iso. Download from:
  https://github.com/DanielFabian/sovereign-codespaces/releases
EOF
    ;;
  *) die "unknown subcommand: $1 (try --help)" ;;
esac
