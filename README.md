# Alpine-NTFS

An automated build system designed to build and boot Alpine Linux directly from an **NTFS** partition inside a virtualized QCOW2 image, using a custom initramfs pivot engine (`ntramfs`).

> WARNING
> **Experimental / Untested on Real Hardware:** This project is currently developed and tested exclusively inside virtual machines (QEMU). It is **not tested on bare-metal hardware**. Running this on real storage devices is at your own risk.
> **WIP Notice:** The standalone ISO target build is currently **unfinished and in progress**. Only the QCOW2 target is fully functional right now.

---

## Architecture & How It Works

Standard Linux systems cannot cleanly boot from NTFS partitions without preparation due to lack of native POSIX symlink translation and early boot drivers. This toolchain solves that by:

1. Creating a dual-partition disk (FAT32 `/boot` + NTFS root).
2. Packaging a lightweight custom initramfs (`ntramfs`) equipped with static BusyBox, kernel filesystem modules, and `ntfs-3g`.
3. Resolving the partition dynamically via UUID and bind-mounting the rootfs subdirectory (`Alpine-NTFS`) to `/mnt_root` before passing control to OpenRC via `switch_root`.

---

## Prerequisites & Dependencies

Make sure your host machine has the following utilities installed:

* **GRUB tools** (`grub-pc-bin`, `grub-install`) — required to install the MBR bootloader onto the target image, even if your host system runs systemd-boot, Limine, or another bootloader.
* **QEMU & disk tools** (`qemu-img`, `qemu-system-x86_64`, `sfdisk`, `losetup`, `partprobe` / `udevadm`).
* **Filesystem utilities** (`dosfstools` for FAT32, `ntfs-3g` / `ntfsprogs` for `mkfs.ntfs`).
* **Archiving & sync tools** (`rsync`, `cpio`, `gzip`, `zstdcat` or `xz`).

---

## Build Instructions

### 1. Obtain Base Alpine Media

Download an official Alpine image and place it directly into the project root:

* **Recommended:** Download the **Virtual** ISO build (e.g. `alpine-virt-*.iso`) and save/symlink it as `alpine.iso` in the project root directory (the Virtual build compiles much faster and keeps the initramfs lean).
* **Alternative ISOs:** Standard or Extended Alpine ISOs can also be dropped in as `alpine.iso`.
* **Alternative Rootfs:** Download an Alpine Minimal Rootfs tarball and unpack it directly into `./rootfs` in the project folder.

### 2. Prepare the Workspace

Extract and stage the base system:
```
./build.sh prepare
```
### 3. Enter the Chroot Environment

Chroot into the staged root filesystem to customize your installation:
```
sudo chroot build/rootfs_patched /bin/sh
```
### 4. Configure & Bootstrap the System

Once inside the chroot, run the built-in system bootstrap command:
```
bootstrap-system
```
* This command installs necessary base packages, registers essential OpenRC services (such as `devfs`, `mdev`, `networking`, `dhcpcd`, `sshd`), sets the hostname to `alpine-ntfs`, and configures credentials.
* You can run `apk add <pkg>` or `rc-update add <service>` now before leaving the chroot.

When done, exit the chroot environment:
```
exit
```
### 5. Build the Disk Image

Pack the configured system, build the custom initramfs, and create the final compressed QCOW2 image:
```
sudo ./build.sh qcow2
```
### 6. Test in QEMU

Run your newly generated NTFS-backed Alpine virtual machine:
```
./run.sh qcow2
```
Default credentials upon boot:

* **Login:** `root`
* **Password:** `root`

---

## License & Third-Party Binaries

This project is licensed under the **GNU General Public License v3.0 (GPLv3)**.

### Bundled Third-Party Binaries

This repository ships pre-compiled binaries inside the `patches/` tree to streamline bootstrapping without requiring host package compilation:

* **`apk-tools` (Alpine Package Manager):** Licensed under **GPLv2**. Upstream source code and original build recipes are available at the official Alpine GitLab repository:
[https://gitlab.alpinelinux.org/alpine/apk-tools](https://www.google.com/search?q=https://gitlab.alpinelinux.org/alpine/apk-tools)
