#!/usr/bin/env bash
# scripts/04_create_image.sh
# Merakit file image (.img) siap burn untuk Orange Pi Zero 3 dan simulasi QEMU
# Versi Ringan & Minimalis: ~1.5GB total image, cma=64M (hemat RAM 512MB), earlycon UART presisi

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_environment.sh"

echo "=========================================================="
echo " [4/4] Merakit Image Sistem Minimalis (.img)"
echo "=========================================================="

IMAGE_NAME="orangepi_zero3_jws.img"
IMAGE_PATH="${OUTPUT_DIR}/${IMAGE_NAME}"
IMAGE_SIZE_MB=1780  # ~1.7GB total disk image (bebas bloatware, hemat tempat SD card)
BOOT_SIZE_MB=96     # 96MB FAT32 boot partition (cukup untuk kernel + DTB + splash)

mkdir -p "${OUTPUT_DIR}" "${BUILD_DIR}/staging_boot"

echo "==> Menyiapkan konten partisi BOOT (staging)..."
STAGING_BOOT="${BUILD_DIR}/staging_boot"
rm -rf "${STAGING_BOOT}"
mkdir -p "${STAGING_BOOT}/splash/frames"

# Salin kernel & DTB ke root partisi BOOT
[ -f "${OUTPUT_DIR}/Image" ] && cp -v "${OUTPUT_DIR}/Image" "${STAGING_BOOT}/"
[ -f "${OUTPUT_DIR}/sun50i-h618-orangepi-zero3.dtb" ] && cp -v "${OUTPUT_DIR}/sun50i-h618-orangepi-zero3.dtb" "${STAGING_BOOT}/"

# Salin aset splash default & frames pra-konversi
[ -f "${ROOT_DIR}/default_assets/splash.bmp" ] && cp -v "${ROOT_DIR}/default_assets/splash.bmp" "${STAGING_BOOT}/splash.bmp"
cp -v "${ROOT_DIR}/default_assets/logo.png" "${STAGING_BOOT}/splash/"
cp -v "${ROOT_DIR}/default_assets/boot.gif" "${STAGING_BOOT}/splash/"
cp -v "${ROOT_DIR}/overlay/usr/share/plymouth/themes/jws-animated"/frame_*.png "${STAGING_BOOT}/splash/frames/" 2>/dev/null || true

# Salin konfigurasi sistem & splash
cp -v "${ROOT_DIR}/configs/splash.conf.example" "${STAGING_BOOT}/splash.conf"
cp -v "${ROOT_DIR}/configs/splash.conf.example" "${STAGING_BOOT}/splash.conf.example"
cp -v "${ROOT_DIR}/configs/system.conf.example" "${STAGING_BOOT}/system.conf"
cp -v "${ROOT_DIR}/configs/system.conf.example" "${STAGING_BOOT}/system.conf.example"
cp -v "${ROOT_DIR}/configs/wifi.conf.example" "${STAGING_BOOT}/wifi.conf.example"

# Konfigurasi boot.cmd & boot.scr standar U-Boot Allwinner sunxi:
# - earlycon: Menggunakan chosen/stdout-path dari DTB (uart0 115200) secara otomatis dan aman (tanpa bug MMIO unaligned)
# - console=tty1 console=ttyS0,115200: UART adalah console terakhir (/dev/console), seluruh teks booting & login keluar di UART (PuTTY)
# - quiet splash loglevel=3 plymouth.ignore-serial-consoles vt.global_cursor_default=0: HDMI murni menampilkan grafis splash
# - Panfrost GPU Mali-G31 aktif untuk akselerasi grafis hardware SDL2 ImGui 60 FPS
# - kernel_addr_r=0x40200000: Memuat kernel langsung di text offset ARM64 agar tidak perlu memmove 43MB
# - cma=64M: Menghemat RAM untuk 512MB RAM SoC H618
cat << 'EOF' > "${STAGING_BOOT}/boot.cmd"
# Boot script for Orange Pi Zero 3 (Allwinner H618)
setenv fdtfile sun50i-h618-orangepi-zero3.dtb
setenv rootdev /dev/mmcblk0p2
setenv kernel_addr_r 0x40200000
setenv bootargs "earlycon console=tty1 console=ttyS0,115200 root=${rootdev} rootwait rw cma=64M quiet splash loglevel=3 plymouth.ignore-serial-consoles vt.global_cursor_default=0"

echo "==> Memuat kernel Image ke ${kernel_addr_r}..."
if fatload mmc 0:1 ${kernel_addr_r} Image; then
    echo "Kernel loaded from Image"
elif fatload mmc 0:1 ${kernel_addr_r} /boot/Image; then
    echo "Kernel loaded from /boot/Image"
elif fatload mmc 0:1 ${kernel_addr_r} /Image; then
    echo "Kernel loaded from /Image"
fi

echo "==> Memuat DTB..."
if fatload mmc 0:1 ${fdt_addr_r} ${fdtfile}; then
    echo "DTB loaded from ${fdtfile}"
elif fatload mmc 0:1 ${fdt_addr_r} /boot/${fdtfile}; then
    echo "DTB loaded from /boot/${fdtfile}"
elif fatload mmc 0:1 ${fdt_addr_r} /${fdtfile}; then
    echo "DTB loaded from /${fdtfile}"
fi

echo "==> Booting Linux kernel via booti..."
booti ${kernel_addr_r} - ${fdt_addr_r}
EOF

# Compile boot.cmd menjadi binary script U-Boot boot.scr
mkimage -C none -A arm64 -T script -d "${STAGING_BOOT}/boot.cmd" "${STAGING_BOOT}/boot.scr"

# Sediakan extlinux/extlinux.conf untuk U-Boot distro boot
mkdir -p "${STAGING_BOOT}/extlinux"
cat << 'EOF' > "${STAGING_BOOT}/extlinux/extlinux.conf"
LABEL OrangePi_Zero3_JWS
    LINUX /Image
    FDT /sun50i-h618-orangepi-zero3.dtb
    APPEND earlycon console=tty1 console=ttyS0,115200 root=/dev/mmcblk0p2 rootwait rw cma=64M quiet splash loglevel=3 plymouth.ignore-serial-consoles vt.global_cursor_default=0
EOF

# Sediakan uEnv.txt di root partisi FAT32 untuk kompatibilitas firmware U-Boot legacy
cat << 'EOF' > "${STAGING_BOOT}/uEnv.txt"
fdtfile=sun50i-h618-orangepi-zero3.dtb
rootdev=/dev/mmcblk0p2
kernel_addr_r=0x40200000
extraargs=cma=64M
bootargs=earlycon console=tty1 console=ttyS0,115200 root=/dev/mmcblk0p2 rootwait rw cma=64M quiet splash loglevel=3 plymouth.ignore-serial-consoles vt.global_cursor_default=0
bootcmd=fatload mmc 0:1 0x40200000 Image; fatload mmc 0:1 ${fdt_addr_r} ${fdtfile}; booti 0x40200000 - ${fdt_addr_r}
EOF

echo "==> Membuat partisi BOOT (FAT32) dengan mformat & mcopy..."
BOOT_IMG="${BUILD_DIR}/boot.img"
rm -f "${BOOT_IMG}"
dd if=/dev/zero of="${BOOT_IMG}" bs=1M count="${BOOT_SIZE_MB}" status=none
mformat -i "${BOOT_IMG}" -F -v "BOOT" ::

# Salin seluruh isi staging_boot ke dalam boot.img FAT32
mcopy -i "${BOOT_IMG}" -s "${STAGING_BOOT}"/* ::

ROOT_IMG="${BUILD_DIR}/rootfs_compact.img"
if [ ! -f "${ROOT_IMG}" ]; then
    ROOT_IMG="${BUILD_DIR}/rootfs.img"
fi

if [ ! -f "${ROOT_IMG}" ]; then
    echo "Error: File rootfs image tidak ditemukan!"
    exit 1
fi

echo "==> Menggunakan Rootfs: ${ROOT_IMG} ($(du -sh "${ROOT_IMG}" | cut -f1))"

echo "==> Merakit disk image akhir (${IMAGE_PATH})..."
rm -f "${IMAGE_PATH}"
dd if=/dev/zero of="${IMAGE_PATH}" bs=1M count=0 seek="${IMAGE_SIZE_MB}" status=none

# Hitung sektor partisi:
# BOOT_SIZE_MB=96 -> 96 * 2048 sektor = 196608 sektor
# Sektor 2048 s/d 198655: Partisi 1 FAT32 (96MB)
# Sektor 198656 s/d end: Partisi 2 EXT4 (ROOTFS ~1420MB)
parted -s "${IMAGE_PATH}" mklabel msdos
parted -s "${IMAGE_PATH}" mkpart primary fat32 2048s 198655s
parted -s "${IMAGE_PATH}" set 1 boot on
parted -s "${IMAGE_PATH}" mkpart primary ext4 198656s 100%

echo "==> Menulis partisi BOOT ke disk image..."
dd if="${BOOT_IMG}" of="${IMAGE_PATH}" bs=512 seek=2048 conv=notrunc status=none

echo "==> Menulis partisi ROOTFS ke disk image..."
dd if="${ROOT_IMG}" of="${IMAGE_PATH}" bs=512 seek=198656 conv=notrunc status=none

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
