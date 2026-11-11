#!/usr/bin/env bash
# scripts/04_create_image.sh
# Merakit file image (.img) siap burn untuk Orange Pi Zero 3 dan simulasi QEMU

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_environment.sh"

echo "=========================================================="
echo " [4/4] Merakit Image Sistem (.img)"
echo "=========================================================="

IMAGE_NAME="orangepi_zero3_jws.img"
IMAGE_PATH="${OUTPUT_DIR}/${IMAGE_NAME}"
IMAGE_SIZE_MB=3200 # ~3.2GB total disk
BOOT_SIZE_MB=128   # 128MB FAT32 boot partition

mkdir -p "${OUTPUT_DIR}" "${BUILD_DIR}/staging_boot"

echo "==> Menyiapkan konten partisi BOOT (staging)..."
STAGING_BOOT="${BUILD_DIR}/staging_boot"
rm -rf "${STAGING_BOOT}"
mkdir -p "${STAGING_BOOT}/splash/frames" "${STAGING_BOOT}/extlinux"

# Salin kernel & DTB
[ -f "${OUTPUT_DIR}/Image" ] && cp -v "${OUTPUT_DIR}/Image" "${STAGING_BOOT}/"
[ -f "${OUTPUT_DIR}/sun50i-h618-orangepi-zero3.dtb" ] && cp -v "${OUTPUT_DIR}/sun50i-h618-orangepi-zero3.dtb" "${STAGING_BOOT}/"

# Salin aset splash default & frames pra-konversi
cp -v "${ROOT_DIR}/default_assets/logo.png" "${STAGING_BOOT}/splash/"
cp -v "${ROOT_DIR}/default_assets/boot.gif" "${STAGING_BOOT}/splash/"
cp -v "${ROOT_DIR}/overlay/usr/share/plymouth/themes/jws-animated"/frame_*.png "${STAGING_BOOT}/splash/frames/" 2>/dev/null || true

# Salin konfigurasi sistem & splash
cp -v "${ROOT_DIR}/configs/splash.conf.example" "${STAGING_BOOT}/splash.conf"
cp -v "${ROOT_DIR}/configs/splash.conf.example" "${STAGING_BOOT}/splash.conf.example"
cp -v "${ROOT_DIR}/configs/system.conf.example" "${STAGING_BOOT}/system.conf"
cp -v "${ROOT_DIR}/configs/system.conf.example" "${STAGING_BOOT}/system.conf.example"
cp -v "${ROOT_DIR}/configs/wifi.conf.example" "${STAGING_BOOT}/wifi.conf.example"

# Konfigurasi Extlinux untuk U-Boot autoboot
cat <<EOF > "${STAGING_BOOT}/extlinux/extlinux.conf"
LABEL OrangePi_Zero3_JWS
    LINUX /Image
    FDT /sun50i-h618-orangepi-zero3.dtb
    APPEND root=/dev/mmcblk0p2 rootwait rw console=tty1 console=ttyS0,115200 splash systemd.show_status=1 loglevel=7 plymouth.ignore-serial-consoles vt.global_cursor_default=0
EOF

echo "==> Membuat partisi BOOT (FAT32) dengan mformat & mcopy..."
BOOT_IMG="${BUILD_DIR}/boot.img"
rm -f "${BOOT_IMG}"
dd if=/dev/zero of="${BOOT_IMG}" bs=1M count="${BOOT_SIZE_MB}" status=none
mformat -i "${BOOT_IMG}" -F -v "BOOT" ::

# Salin seluruh isi staging_boot ke dalam boot.img FAT32
mcopy -i "${BOOT_IMG}" -s "${STAGING_BOOT}"/* ::

ROOT_IMG="${BUILD_DIR}/rootfs.img"
if [ ! -f "${ROOT_IMG}" ]; then
    echo "Error: File ${ROOT_IMG} tidak ditemukan!"
    exit 1
fi

echo "==> Merakit disk image akhir (${IMAGE_PATH})..."
rm -f "${IMAGE_PATH}"
dd if=/dev/zero of="${IMAGE_PATH}" bs=1M count=0 seek="${IMAGE_SIZE_MB}" status=none

# Hitung sektor partisi:
# Sektor 2048 s/d 264191: Partisi 1 FAT32 (128MB)
# Sektor 264192 s/d end: Partisi 2 EXT4 (ROOTFS)
parted -s "${IMAGE_PATH}" mklabel msdos
parted -s "${IMAGE_PATH}" mkpart primary fat32 2048s 264191s
parted -s "${IMAGE_PATH}" set 1 boot on
parted -s "${IMAGE_PATH}" mkpart primary ext4 264192s 100%

echo "==> Menulis partisi BOOT ke disk image..."
dd if="${BOOT_IMG}" of="${IMAGE_PATH}" bs=512 seek=2048 conv=notrunc status=none

echo "==> Menulis partisi ROOTFS ke disk image..."
dd if="${ROOT_IMG}" of="${IMAGE_PATH}" bs=512 seek=264192 conv=notrunc status=none

# Tulis bootloader Allwinner SPL ke offset 8KB
UBOOT_BIN="${OUTPUT_DIR}/u-boot-sunxi-with-spl.bin"
if [ -f "${UBOOT_BIN}" ]; then
    echo "==> Menulis U-Boot SPL ke offset 8KB..."
    dd if="${UBOOT_BIN}" of="${IMAGE_PATH}" bs=1k seek=8 conv=notrunc status=none
fi

sync

echo "=========================================================="
echo " SUKSES: Image siap di ${IMAGE_PATH}"
echo " Ukuran Image: $(du -sh "${IMAGE_PATH}" | cut -f1)"
echo "=========================================================="
