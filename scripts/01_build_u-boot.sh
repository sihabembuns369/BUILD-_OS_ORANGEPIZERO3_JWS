#!/usr/bin/env bash
# scripts/01_build_u-boot.sh
# Build ARM Trusted Firmware (BL31) dan U-Boot untuk Orange Pi Zero 3 (Allwinner H618)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_environment.sh"

echo "=========================================================="
echo " [1/4] Membangun ARM Trusted Firmware (BL31) & U-Boot"
echo "=========================================================="

mkdir -p "${DOWNLOAD_DIR}" "${OUTPUT_DIR}"

# 1. ARM Trusted Firmware (ATF)
if [ ! -d "${ATF_DIR}" ]; then
    echo "==> Mengunduh ARM Trusted Firmware..."
    git clone --depth 1 https://github.com/ARM-software/arm-trusted-firmware.git "${ATF_DIR}"
fi

cd "${ATF_DIR}"
echo "==> Mengompilasi ARM Trusted Firmware (PLAT=sun50i_h616)..."
# H618 berbagi arsitektur power controller & MMU dengan H616 pada ATF
if [ -d "plat/allwinner/sun50i_h616" ]; then
    ATF_PLAT="sun50i_h616"
else
    ATF_PLAT="sun50i_h6"
fi

make CROSS_COMPILE="${CROSS_COMPILE}" PLAT="${ATF_PLAT}" DEBUG=1 bl31 -j"${NPROC}"

BL31_BIN="${ATF_DIR}/build/${ATF_PLAT}/debug/bl31.bin"
if [ ! -f "${BL31_BIN}" ]; then
    BL31_BIN="${ATF_DIR}/build/${ATF_PLAT}/release/bl31.bin"
fi

if [ ! -f "${BL31_BIN}" ]; then
    echo "Error: BL31 binary tidak ditemukan di ${BL31_BIN}!"
    exit 1
fi
echo "==> BL31 siap: ${BL31_BIN}"

# 2. U-Boot
if [ ! -d "${UBOOT_DIR}" ]; then
    echo "==> Mengunduh Das U-Boot..."
    git clone --depth 1 https://github.com/u-boot/u-boot.git "${UBOOT_DIR}"
fi

cd "${UBOOT_DIR}"
echo "==> Menyiapkan konfigurasi U-Boot (orangepi_zero3_defconfig)..."
make CROSS_COMPILE="${CROSS_COMPILE}" orangepi_zero3_defconfig

echo "==> Mengompilasi U-Boot dengan BL31..."
export BL31="${BL31_BIN}"
make CROSS_COMPILE="${CROSS_COMPILE}" -j"${NPROC}"

if [ -f "u-boot-sunxi-with-spl.bin" ]; then
    cp -v u-boot-sunxi-with-spl.bin "${OUTPUT_DIR}/"
    echo "=========================================================="
    echo " SUKSES: Bootloader siap di ${OUTPUT_DIR}/u-boot-sunxi-with-spl.bin"
    echo "=========================================================="
else
    echo "Error: File u-boot-sunxi-with-spl.bin tidak ditemukan setelah kompilasi!"
    exit 1
fi
