#!/bin/sh
set -e
. "$(dirname "$0")/../config.env"

echo "=== Staging Patched Rootfs Workspace ==="
rm -rf "$PATCHED_ROOTFS"
mkdir -p "$PATCHED_ROOTFS"

echo "[+] Copying pristine rootfs to build workspace..."
rsync -a "$ROOTFS_DIR/" "$PATCHED_ROOTFS/"

if [ -d "$PATCHES_DIR" ] && [ -n "$(ls -A "$PATCHES_DIR" 2>/dev/null)" ]; then
    echo "=== Applying overlay patches from $PATCHES_DIR ==="
    # --keep-dirlinks treats symlinked dirs (like /lib -> /usr/lib) as actual dirs
    rsync -a --keep-dirlinks "$PATCHES_DIR/" "$PATCHED_ROOTFS/"
else
    echo "[+] No overlay patches found in $PATCHES_DIR, skipping."
fi

if [ -f /etc/resolv.conf ]; then
    echo "[+] Copying host DNS configuration (/etc/resolv.conf)..."
    mkdir -p "$PATCHED_ROOTFS/etc"
    cp -L /etc/resolv.conf "$PATCHED_ROOTFS/etc/resolv.conf"
fi

if [ -n "$SUDO_USER" ]; then
    SUDO_GROUP=$(id -gn "$SUDO_USER" 2>/dev/null || echo "$SUDO_USER")
    chown -R "$SUDO_USER:$SUDO_GROUP" "$PATCHES_DIR" 2>/dev/null || true
    chmod -R u+rwX,go+rX "$PATCHES_DIR" 2>/dev/null || true
fi

echo "[+] Rootfs overlay complete."