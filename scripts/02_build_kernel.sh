#!/usr/bin/env bash
# scripts/02_build_kernel.sh
# Build Kernel Linux Mainline untuk Orange Pi Zero 3 (Allwinner H618) & QEMU virt

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_environment.sh"

echo "=========================================================="
echo " [2/4] Membangun Kernel Linux Mainline ARM64"
echo "=========================================================="

mkdir -p "${DOWNLOAD_DIR}" "${OUTPUT_DIR}" "${OUTPUT_DIR}/modules"

# Clone Linux stable jika belum ada
if [ ! -d "${KERNEL_DIR}" ]; then
    echo "==> Mengunduh Kernel Linux (stable)..."
    git clone --depth 1 --branch "${KERNEL_BRANCH}" https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git "${KERNEL_DIR}" || \
    git clone --depth 1 https://github.com/torvalds/linux.git "${KERNEL_DIR}"
fi

cd "${KERNEL_DIR}"

echo "==> Menyiapkan defconfig arm64..."
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" defconfig

echo "==> Menerapkan konfigurasi hardware Orange Pi Zero 3 & Virtio QEMU..."
./scripts/config --enable CONFIG_DRM_SUN4I
./scripts/config --enable CONFIG_DRM_SUN8I_MIXER
./scripts/config --enable CONFIG_DRM_SUN8I_DW_HDMI
./scripts/config --enable CONFIG_DRM_SUN4I_HDMI
./scripts/config --enable CONFIG_DRM_PANFROST
./scripts/config --enable CONFIG_FRAMEBUFFER_CONSOLE
./scripts/config --enable CONFIG_LOGO

# UART Serial Console
./scripts/config --enable CONFIG_SERIAL_8250_SUNXI
./scripts/config --enable CONFIG_SERIAL_8250_CONSOLE

# IR Remote / Consumer IR (GPIO & Sunxi)
./scripts/config --enable CONFIG_RC_CORE
./scripts/config --enable CONFIG_LIRC
./scripts/config --module CONFIG_IR_GPIO_CIR
./scripts/config --module CONFIG_IR_SUNXI
./scripts/config --module CONFIG_IR_RC5_DECODER
./scripts/config --module CONFIG_IR_NEC_DECODER

# Audio (ALSA & Allwinner SoC)
./scripts/config --enable CONFIG_SOUND
./scripts/config --enable CONFIG_SND
./scripts/config --enable CONFIG_SND_SOC
./scripts/config --enable CONFIG_SND_SUN4I_CODEC
./scripts/config --enable CONFIG_SND_SUN8I_CODEC
./scripts/config --enable CONFIG_SND_SUN8I_CODEC_ANALOG

# Networking, WiFi & Bluetooth
./scripts/config --enable CONFIG_NET_ETHERNET
./scripts/config --enable CONFIG_SUN8I_EMAC
./scripts/config --enable CONFIG_WIRELESS
./scripts/config --enable CONFIG_CFG80211
./scripts/config --enable CONFIG_MAC80211
./scripts/config --module CONFIG_BT
./scripts/config --module CONFIG_BT_HCIUART

# QEMU Virt Support (untuk verifikasi simulasi mulus)
./scripts/config --enable CONFIG_VIRTIO
./scripts/config --enable CONFIG_VIRTIO_PCI
./scripts/config --enable CONFIG_VIRTIO_NET
./scripts/config --enable CONFIG_VIRTIO_BLK
./scripts/config --enable CONFIG_VIRTIO_INPUT
./scripts/config --enable CONFIG_DRM_VIRTIO_GPU

make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" olddefconfig

echo "==> Mengompilasi Kernel Image, Modul, dan DTB..."
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" -j"${NPROC}" Image modules dtbs

echo "==> Memasang modul kernel ke output directory..."
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_MOD_PATH="${OUTPUT_DIR}/modules_install" modules_install

# Salin artefak kernel
cp -v arch/arm64/boot/Image "${OUTPUT_DIR}/"

# Salin DTB Orange Pi Zero 3
DTB_FILE="arch/arm64/boot/dts/allwinner/sun50i-h618-orangepi-zero3.dtb"
if [ -f "${DTB_FILE}" ]; then
    cp -v "${DTB_FILE}" "${OUTPUT_DIR}/"
elif [ -f "arch/arm64/boot/dts/allwinner/sun50i-h616-orangepi-zero2.dtb" ]; then
    # Fallback jika nama dts h616
    cp -v arch/arm64/boot/dts/allwinner/sun50i-h616-orangepi-zero2.dtb "${OUTPUT_DIR}/"
fi

# Simpan .config kernel yang digunakan ke repo
cp -v .config "${ROOT_DIR}/configs/kernel_arm64_defconfig"

echo "=========================================================="
echo " SUKSES: Kernel Image dan DTB siap di ${OUTPUT_DIR}/"
echo "=========================================================="
