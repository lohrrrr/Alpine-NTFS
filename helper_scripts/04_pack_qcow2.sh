#!/bin/sh
set -e
. "$(dirname "$0")/../config.env"

RAW_IMG="$BUILD_DIR/${IMAGE_NAME}.raw"
MOUNT_BOOT="/tmp/alpine_boot_mount"
MOUNT_ROOT="/tmp/alpine_root_mount"
LOCAL_KERNEL="$BUILD_DIR/vmlinuz"
LOCAL_INITRD="$BUILD_DIR/initramfs.cpio.gz"

if [ ! -f "$LOCAL_KERNEL" ] && [ -f "$BASE_DIR/vmlinuz" ]; then
    cp "$BASE_DIR/vmlinuz" "$LOCAL_KERNEL"
fi

if [ ! -d "$PATCHED_ROOTFS" ] || [ ! -f "$LOCAL_KERNEL" ] || [ ! -f "$LOCAL_INITRD" ]; then
    echo "ERROR: Missing required artifacts to pack image."
    exit 1
fi

echo "=== 1. Allocating Raw Disk Storage (${DISK_SIZE_MB}MB) ==="
dd if=/dev/zero of="$RAW_IMG" bs=1M count=0 seek="$DISK_SIZE_MB"

sfdisk "$RAW_IMG" << EOF
label: dos
unit: sectors

1 : size=${BOOT_SIZE_MB}M, type=b, bootable
2 : type=7
EOF

echo "=== 2. Attaching Disk to Free Loop Device ==="
LOOP_DEV=$(sudo losetup -fP --show "$RAW_IMG")
sudo partprobe "$LOOP_DEV" 2>/dev/null || sudo udevadm settle

cleanup() {
    echo "=== Cleaning up loop mounts ==="
    sudo umount -f "$MOUNT_BOOT" 2>/dev/null || true
    sudo umount -f "$MOUNT_ROOT" 2>/dev/null || true
    if [ -n "$LOOP_DEV" ]; then sudo losetup -d "$LOOP_DEV" 2>/dev/null || true; fi
    rm -rf "$MOUNT_BOOT" "$MOUNT_ROOT" "$RAW_IMG" 2>/dev/null || true
}
trap cleanup EXIT

echo "=== 3. Formatting Partitions ==="
sudo mkfs.vfat -F 32 -n "BOOT" "${LOOP_DEV}p1"

if command -v mkfs.ntfs >/dev/null 2>&1; then
    sudo mkfs.ntfs -Q -F -L "Alpine-NTFS" "${LOOP_DEV}p2"
else
    sudo mkntfs -Q -F -L "Alpine-NTFS" "${LOOP_DEV}p2"
fi

NTFS_UUID=$(sudo blkid -s UUID -o value "${LOOP_DEV}p2")
BOOT_UUID=$(sudo blkid -s UUID -o value "${LOOP_DEV}p1")

echo "[+] NTFS Root UUID: $NTFS_UUID"
echo "[+] FAT32 Boot UUID: $BOOT_UUID"

echo "=== 4. Populating Filesystems ==="
mkdir -p "$MOUNT_BOOT" "$MOUNT_ROOT"
sudo mount "${LOOP_DEV}p1" "$MOUNT_BOOT"
sudo mount -t ntfs-3g -o permissions "${LOOP_DEV}p2" "$MOUNT_ROOT"

sudo mkdir -p "$MOUNT_ROOT/Alpine-NTFS"
sudo cp -a "$PATCHED_ROOTFS/." "$MOUNT_ROOT/Alpine-NTFS/"

echo "[+] Ensuring core executable entrypoints exist as real binaries..."
BUSYBOX_SRC=""
if [ -f "$MOUNT_ROOT/Alpine-NTFS/bin/busybox" ]; then
    BUSYBOX_SRC="$MOUNT_ROOT/Alpine-NTFS/bin/busybox"
elif [ -f "$MOUNT_ROOT/Alpine-NTFS/bin/busybox.static" ]; then
    BUSYBOX_SRC="$MOUNT_ROOT/Alpine-NTFS/bin/busybox.static"
fi

if [ -n "$BUSYBOX_SRC" ]; then
    sudo rm -f "$MOUNT_ROOT/Alpine-NTFS/sbin/init" "$MOUNT_ROOT/Alpine-NTFS/bin/sh"
    sudo cp "$BUSYBOX_SRC" "$MOUNT_ROOT/Alpine-NTFS/sbin/init"
    sudo cp "$BUSYBOX_SRC" "$MOUNT_ROOT/Alpine-NTFS/bin/sh"
    sudo chmod 755 "$MOUNT_ROOT/Alpine-NTFS/sbin/init" "$MOUNT_ROOT/Alpine-NTFS/bin/sh"
fi

sudo mkdir -p "$MOUNT_BOOT/boot/grub"
sudo cp "$LOCAL_KERNEL" "$MOUNT_BOOT/boot/vmlinuz"
sudo cp "$LOCAL_INITRD" "$MOUNT_BOOT/boot/initramfs.cpio.gz"

cat << EOF | sudo tee "$MOUNT_BOOT/boot/grub/grub.cfg" > /dev/null
set timeout=2
set default=0

menuentry "Alpine Linux (NTFS Root)" {
    search --no-floppy --fs-uuid --set=root $BOOT_UUID
    linux /boot/vmlinuz root=UUID=$NTFS_UUID rw modules=loop,fuse,ntfs3 quiet
    initrd /boot/initramfs.cpio.gz
}
EOF

echo "=== 5. Installing GRUB MBR ==="
sudo grub-install --target=i386-pc --boot-directory="$MOUNT_BOOT/boot" "$LOOP_DEV"

echo "=== 6. Converting Raw Image to Compressed QCOW2 ==="
sudo umount -f "$MOUNT_BOOT"
sudo umount -f "$MOUNT_ROOT"
sudo losetup -d "$LOOP_DEV"
LOOP_DEV=""

qemu-img convert -c -f raw -O qcow2 "$RAW_IMG" "$OUTPUT_QCOW2"
rm -f "$RAW_IMG"

if [ -n "$SUDO_USER" ]; then
    chown "$SUDO_USER:$(id -gn "$SUDO_USER")" "$OUTPUT_QCOW2" 2>/dev/null || true
fi

echo "[+] Successfully generated QCOW2 image: $OUTPUT_QCOW2"