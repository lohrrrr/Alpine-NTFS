#!/bin/sh
set -e
. "$(dirname "$0")/../config.env"

INITRAMFS_STAGING="$BUILD_DIR/initramfs_staging"
OUTPUT_INITRD="$BUILD_DIR/initramfs.cpio.gz"
BUSYBOX_BIN="$PATCHED_ROOTFS/bin/busybox.static"

[ ! -f "$BUSYBOX_BIN" ] && BUSYBOX_BIN="$PATCHED_ROOTFS/bin/busybox"

if [ ! -f "$BUSYBOX_BIN" ]; then
    echo "ERROR: BusyBox binary not found in $PATCHED_ROOTFS/bin"
    exit 1
fi

if [ ! -f "$BASE_DIR/ntramfs/init" ]; then
    echo "ERROR: Missing source script at $BASE_DIR/ntramfs/init"
    exit 1
fi

echo "=== Cleaning & Creating Initramfs Workspace ==="
rm -rf "$INITRAMFS_STAGING" "$OUTPUT_INITRD"
mkdir -p "$INITRAMFS_STAGING/bin" \
         "$INITRAMFS_STAGING/sbin" \
         "$INITRAMFS_STAGING/usr/bin" \
         "$INITRAMFS_STAGING/usr/sbin" \
         "$INITRAMFS_STAGING/proc" \
         "$INITRAMFS_STAGING/sys" \
         "$INITRAMFS_STAGING/dev" \
         "$INITRAMFS_STAGING/mnt_raw" \
         "$INITRAMFS_STAGING/mnt_root" \
         "$INITRAMFS_STAGING/lib/modules"

echo "=== Installing BusyBox ==="
cp "$BUSYBOX_BIN" "$INITRAMFS_STAGING/busybox"
cp "$BUSYBOX_BIN" "$INITRAMFS_STAGING/bin/busybox"
chmod +x "$INITRAMFS_STAGING/busybox" "$INITRAMFS_STAGING/bin/busybox"

ln -sf /busybox "$INITRAMFS_STAGING/bin/sh"
ln -sf /busybox "$INITRAMFS_STAGING/bin/blkid"
ln -sf /busybox "$INITRAMFS_STAGING/bin/grep"
ln -sf /busybox "$INITRAMFS_STAGING/bin/cut"

echo "=== Copying Userspace NTFS Tools and Shared Libraries ==="
find "$PATCHED_ROOTFS" -name ntfs-3g -type f -exec cp {} "$INITRAMFS_STAGING/bin/" \; -quit

if [ -d "$PATCHED_ROOTFS/lib" ]; then
    cp -a "$PATCHED_ROOTFS/lib/." "$INITRAMFS_STAGING/lib/" 2>/dev/null || true
fi
if [ -d "$PATCHED_ROOTFS/usr/lib" ]; then
    mkdir -p "$INITRAMFS_STAGING/usr/lib"
    cp -a "$PATCHED_ROOTFS/usr/lib/." "$INITRAMFS_STAGING/usr/lib/" 2>/dev/null || true
fi

echo "=== Copying Storage and Filesystem Modules ==="
MODULE_DEST="$INITRAMFS_STAGING/lib/modules"
KERNEL_MOD_DIR=$(ls -d "$PATCHED_ROOTFS/lib/modules/"* 2>/dev/null | head -n 1)

DRIVERS="virtio_blk virtio_pci virtio_ring virtio scsi_mod sd_mod ahci libata ntfs ntfs3 fuse loop"

if [ -d "$KERNEL_MOD_DIR" ]; then
    for driver in $DRIVERS; do
        find "$KERNEL_MOD_DIR" -name "${driver}.ko*" -type f -exec cp {} "$MODULE_DEST/" \; 2>/dev/null || true
    done
    find "$MODULE_DEST" -name "*.ko.gz" -exec gzip -d {} + 2>/dev/null || true
    find "$MODULE_DEST" -name "*.ko.xz" -exec xz -d {} + 2>/dev/null || true
    find "$MODULE_DEST" -name "*.ko.zst" -exec zstd -d --rm {} + 2>/dev/null || true
fi

echo "=== Installing Target Init Script from $BASE_DIR/ntramfs/init ==="
cp -f "$BASE_DIR/ntramfs/init" "$INITRAMFS_STAGING/init"
chmod +x "$INITRAMFS_STAGING/init"

echo "=== Compressing to $OUTPUT_INITRD ==="
(
    cd "$INITRAMFS_STAGING"
    find . -print0 | cpio --null -ov --format=newc | gzip -9 > "$OUTPUT_INITRD"
)

rm -rf "$INITRAMFS_STAGING"

if [ -n "$SUDO_USER" ]; then
    chown "$SUDO_USER:$(id -gn "$SUDO_USER")" "$OUTPUT_INITRD" 2>/dev/null || true
fi

echo "[+] Initramfs build finished successfully: $OUTPUT_INITRD"