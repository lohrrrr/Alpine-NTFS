#!/bin/sh
set -e
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$BASE_DIR/config.env"

MODE="${1:-qcow2}"

if [ "$MODE" = "qcow2" ]; then
    echo "Launching QCOW2 instance..."
    qemu-system-x86_64 \
        -drive "file=$OUTPUT_QCOW2,format=qcow2,if=virtio" \
        -net nic,model=virtio \
        -net user \
        -m 2G \
        -enable-kvm \
        -cpu host \
        -smp 2
elif [ "$MODE" = "iso" ]; then
    echo "Launching Live ISO Installer instance..."
    # Spawns a 5GB blank disk (vda) alongside the optical media (cdrom)
    TEST_DISK="$BUILD_DIR/install_target_disk.img"
    [ ! -f "$TEST_DISK" ] && qemu-img create -f qcow2 "$TEST_DISK" 5G

    qemu-system-x86_64 \
        -cdrom "$OUTPUT_ISO" \
        -drive "file=$TEST_DISK,format=qcow2,if=virtio" \
        -boot d \
        -net nic,model=virtio \
        -net user \
        -m 2G \
        -enable-kvm \
        -cpu host \
        -smp 2
else
    echo "Usage: $0 [qcow2|iso]"
    exit 1
fi