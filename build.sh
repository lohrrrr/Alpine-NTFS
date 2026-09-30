#!/bin/sh
set -e
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$BASE_DIR/config.env"

ACTION="$1"

case "$ACTION" in
    prepare)
        echo "=== [1/2] Extracting Rootfs & Kernel from ISO ==="
        "$BASE_DIR/helper_scripts/01_extract_rootfs.sh"

        echo "=== [2/2] Staging Patched Rootfs Workspace ==="
        "$BASE_DIR/helper_scripts/02_patch_rootfs.sh"

        echo ""
        echo "[+] Ready. Run this to enter:"
        echo "    sudo chroot build/rootfs_patched /bin/sh"
        ;;

    qcow2)
        if [ ! -d "$PATCHED_ROOTFS" ]; then
            echo "ERROR: Patched rootfs does not exist. Run './build.sh prepare' first."
            exit 1
        fi
        echo "=== [1/2] Generating NTFS-Compatible Initramfs ==="
        "$BASE_DIR/helper_scripts/03_build_initramfs.sh"

        echo "=== [2/2] Assembling NTFS QCOW2 Disk ==="
        "$BASE_DIR/helper_scripts/04_pack_qcow2.sh"
        ;;

    iso)
        if [ ! -d "$PATCHED_ROOTFS" ]; then
            echo "ERROR: Patched rootfs does not exist. Run './build.sh prepare' first."
            exit 1
        fi
        echo "=== [1/2] Generating Initramfs ==="
        "$BASE_DIR/helper_scripts/03_build_initramfs.sh"

        echo "=== [2/2] Generating SquashFS Live Installer ISO ==="
        "$BASE_DIR/helper_scripts/05_pack_iso.sh"
        ;;

    *)
        echo "Usage: $0 {prepare|qcow2|iso}"
        exit 1
        ;;
esac