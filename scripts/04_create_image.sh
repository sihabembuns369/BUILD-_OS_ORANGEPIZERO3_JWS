#!/usr/bin/env bash
# scripts/04_create_image.sh
# Merakit file image (.img) siap burn untuk Orange Pi Zero 3 dan simulasi QEMU

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_environment.sh"

echo "=========================================================="
echo " [4/4] Merakit Image Sistem (.img)"
echo "=========================================================="

if [ "$EUID" -ne 0 ]; then
    echo "Skrip ini memerlukan hak akses root (sudo) untuk partisi dan mounting loopback."
    exec sudo -E bash "$0" "$@"
fi

IMAGE_NAME="orangepi_zero3_jws.img"
IMAGE_PATH="${OUTPUT_DIR}/${IMAGE_NAME}"
IMAGE_SIZE_MB=3072 # 3GB

mkdir -p "${OUTPUT_DIR}"

echo "==> Membuat file sparse image berukuran ${IMAGE_SIZE_MB}MB..."
rm -f "${IMAGE_PATH}"
dd if=/dev/zero of="${IMAGE_PATH}" bs=1M count=0 seek="${IMAGE_SIZE_MB}"

echo "==> Membuat tabel partisi MBR (DOS)..."
# Partisi 1: FAT32 (128MB) untuk /boot (offset 2MB ke 130MB)
# Partisi 2: EXT4 (sisa kapasitas) untuk / (rootfs)
parted -s "${IMAGE_PATH}" mklabel msdos
parted -s "${IMAGE_PATH}" mkpart primary fat32 2048s 264191s
parted -s "${IMAGE_PATH}" set 1 boot on
parted -s "${IMAGE_PATH}" mkpart primary ext4 264192s 100%

# Setup Loop Device
LOOP_DEV=$(losetup -fP --show "${IMAGE_PATH}")
echo "==> Loop device terpasang di: ${LOOP_DEV}"

cleanup() {
    echo "==> Melepaskan mount dan loop device..."
    umount -q /tmp/jws_mnt_root/boot 2>/dev/null || true
    umount -q /tmp/jws_mnt_root 2>/dev/null || true
    rm -rf /tmp/jws_mnt_root
    losetup -d "${LOOP_DEV}" 2>/dev/null || true
}
trap cleanup EXIT

BOOT_DEV="${LOOP_DEV}p1"
ROOT_DEV="${LOOP_DEV}p2"

echo "==> Memformat partisi 1 (FAT32 BOOT) dan partisi 2 (EXT4 ROOT)..."
mkfs.vfat -F 32 -n "BOOT" "${BOOT_DEV}"
mkfs.ext4 -F -L "ROOTFS" -O ^metadata_csum "${ROOT_DEV}"

# Pasang U-Boot SPL jika file tersedia
UBOOT_BIN="${OUTPUT_DIR}/u-boot-sunxi-with-spl.bin"
if [ -f "${UBOOT_BIN}" ]; then
    echo "==> Menulis U-Boot SPL ke offset 8KB loop device..."
    dd if="${UBOOT_BIN}" of="${LOOP_DEV}" bs=1k seek=8 conv=notrunc status=none
fi

mkdir -p /tmp/jws_mnt_root
mount "${ROOT_DEV}" /tmp/jws_mnt_root

echo "==> Menyalin rootfs ke partisi root..."
cp -a "${ROOTFS_DIR}"/* /tmp/jws_mnt_root/

mkdir -p /tmp/jws_mnt_root/boot
mount "${BOOT_DEV}" /tmp/jws_mnt_root/boot

echo "==> Menyalin kernel, DTB, dan file splash ke partisi BOOT..."
[ -f "${OUTPUT_DIR}/Image" ] && cp -v "${OUTPUT_DIR}/Image" /tmp/jws_mnt_root/boot/
[ -f "${OUTPUT_DIR}/sun50i-h618-orangepi-zero3.dtb" ] && cp -v "${OUTPUT_DIR}/sun50i-h618-orangepi-zero3.dtb" /tmp/jws_mnt_root/boot/

# Buat direktori splash di FAT32 partisi boot
mkdir -p /tmp/jws_mnt_root/boot/splash /tmp/jws_mnt_root/boot/splash/frames
cp -v "${ROOT_DIR}/default_assets/logo.png" /tmp/jws_mnt_root/boot/splash/
cp -v "${ROOT_DIR}/default_assets/boot.gif" /tmp/jws_mnt_root/boot/splash/

# Salin template config dan config aktif
cp -v "${ROOT_DIR}/configs/splash.conf.example" /tmp/jws_mnt_root/boot/
cp -v "${ROOT_DIR}/configs/splash.conf.example" /tmp/jws_mnt_root/boot/splash.conf

cp -v "${ROOT_DIR}/configs/system.conf.example" /tmp/jws_mnt_root/boot/
cp -v "${ROOT_DIR}/configs/system.conf.example" /tmp/jws_mnt_root/boot/system.conf

cp -v "${ROOT_DIR}/configs/wifi.conf.example" /tmp/jws_mnt_root/boot/

# Buat konfigurasi extlinux (standar U-Boot generic distro boot)
mkdir -p /tmp/jws_mnt_root/boot/extlinux
cat <<EOF > /tmp/jws_mnt_root/boot/extlinux/extlinux.conf
LABEL OrangePi_Zero3_JWS
    LINUX /Image
    FDT /sun50i-h618-orangepi-zero3.dtb
    APPEND root=/dev/mmcblk0p2 rootwait rw console=tty1 console=ttyS0,115200 quiet splash loglevel=3 vt.global_cursor_default=0
EOF

# Konfigurasi /etc/fstab
cat <<EOF > /tmp/jws_mnt_root/etc/fstab
# /etc/fstab: static file system information
LABEL=ROOTFS    /               ext4    errors=remount-ro,noatime    0   1
LABEL=BOOT      /boot           vfat    defaults                     0   2
EOF

echo "==> Sinkronisasi berkas ke disk..."
sync

echo "=========================================================="
echo " SUKSES: Image siap di ${IMAGE_PATH}"
echo " Ukuran Image: $(du -sh "${IMAGE_PATH}" | cut -f1)"
echo "=========================================================="
