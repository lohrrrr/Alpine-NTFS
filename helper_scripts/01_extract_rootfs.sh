#!/bin/sh
set -e
. "$(dirname "$0")/../config.env"

ISO_FILE=$(find "$BASE_DIR" -maxdepth 1 -iname "*alpine*.iso" | head -n 1)

if [ -z "$ISO_FILE" ]; then
    echo "ERROR: No 'alpine.iso' found in $BASE_DIR."
    exit 1
fi

echo "=== Processing ISO: $ISO_FILE ==="
mkdir -p "$ROOTFS_DIR" "$BUILD_DIR"
ISO_MNT="/tmp/alpine_iso_mount"
mkdir -p "$ISO_MNT"

cleanup_iso() {
    sudo umount -f "$ISO_MNT" 2>/dev/null || true
    rmdir "$ISO_MNT" 2>/dev/null || true
}
trap cleanup_iso EXIT

sudo mount -o loop,ro "$ISO_FILE" "$ISO_MNT"

echo "=== Extracting Kernel Binary from ISO ==="
KERNEL_SRC=$(find "$ISO_MNT/boot" -name "vmlinuz*" | head -n 1)
if [ -n "$KERNEL_SRC" ]; then
    cp "$KERNEL_SRC" "$BUILD_DIR/vmlinuz"
    echo "[+] Extracted kernel -> $BUILD_DIR/vmlinuz"
else
    echo "ERROR: No vmlinuz found in $ISO_FILE:/boot"
    exit 1
fi

if [ -x "$ROOTFS_DIR/bin/sh" ] || [ -x "$ROOTFS_DIR/bin/busybox" ]; then
    echo "[+] Valid base rootfs found at $ROOTFS_DIR. Skipping extraction."
    exit 0
fi

STOCK_INITRD=$(find "$ISO_MNT/boot" -name "initramfs*" | head -n 1)

if [ -z "$STOCK_INITRD" ]; then
    echo "ERROR: No initramfs found in $ISO_MNT/boot"
    exit 1
fi

echo "=== Unpacking Base Alpine System from $STOCK_INITRD ==="
cd "$ROOTFS_DIR"

if zstd -t "$STOCK_INITRD" >/dev/null 2>&1; then
    echo "[+] Format: zstd compressed archive"
    zstdcat "$STOCK_INITRD" | cpio -idm
elif gzip -t "$STOCK_INITRD" >/dev/null 2>&1; then
    echo "[+] Format: gzip compressed archive"
    zcat "$STOCK_INITRD" | cpio -idm
elif xz -t "$STOCK_INITRD" >/dev/null 2>&1; then
    echo "[+] Format: xz compressed archive"
    xzcat "$STOCK_INITRD" | cpio -idm
else
    echo "ERROR: Unsupported or corrupted initramfs compression format."
    exit 1
fi
cd "$BASE_DIR"

MODLOOP_FILE=$(find "$ISO_MNT/boot" -name "modloop*" | head -n 1)
if [ -n "$MODLOOP_FILE" ]; then
    echo "=== Extracting Kernel Modules from $MODLOOP_FILE ==="
    MODLOOP_MNT="/tmp/alpine_modloop_mount"
    mkdir -p "$MODLOOP_MNT"
    sudo mount -o loop,ro "$MODLOOP_FILE" "$MODLOOP_MNT"
    mkdir -p "$ROOTFS_DIR/lib/modules"
    cp -a "$MODLOOP_MNT/modules/." "$ROOTFS_DIR/lib/modules/" 2>/dev/null || \
    cp -a "$MODLOOP_MNT/." "$ROOTFS_DIR/lib/modules/" 2>/dev/null || true
    sudo umount -f "$MODLOOP_MNT"
    rmdir "$MODLOOP_MNT" 2>/dev/null || true
fi

# I duplicated it here because why not
mkdir -p "$ROOTFS_DIR/etc/apk"
cat << 'EOF' > "$ROOTFS_DIR/etc/apk/repositories"
https://dl-cdn.alpinelinux.org/alpine/latest-stable/main
https://dl-cdn.alpinelinux.org/alpine/latest-stable/community
EOF

echo "[+] Successfully unpacked pristine Alpine rootfs into $ROOTFS_DIR"