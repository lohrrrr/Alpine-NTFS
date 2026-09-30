#!/bin/sh
set -e

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$BASE_DIR/config.env"

echo "=== Cleaning Up Build Artifacts and Mounts ==="

sudo umount -f /tmp/alpine_boot_mount 2>/dev/null || true
sudo umount -f /tmp/alpine_root_mount 2>/dev/null || true
sudo umount -f /tmp/alpine_iso_mount 2>/dev/null || true
rm -rf /tmp/alpine_boot_mount /tmp/alpine_root_mount /tmp/alpine_iso_mount 2>/dev/null || true

for dev in $(losetup -j "$BUILD_DIR/${IMAGE_NAME}.raw" 2>/dev/null | cut -d: -f1); do
    echo "[-] Detaching loop device: $dev"
    sudo losetup -d "$dev" 2>/dev/null || true
done

if [ -d "$BUILD_DIR" ]; then
    echo "[-] Removing contents of: $BUILD_DIR"
    sudo rm -rf "${BUILD_DIR:?}"/*
fi

rm -f "$BASE_DIR/initramfs.cpio.gz" "$BASE_DIR/Alpine-NTFS.qcow2" "$BASE_DIR/Alpine-NTFS.img" 2>/dev/null || true

echo "[+] Clean complete. Workspace is ready for a fresh build."