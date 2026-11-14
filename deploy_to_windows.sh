#!/usr/bin/env bash
# ==============================================================================
# Script Deploy Image OS Orange Pi Zero 3 ke Windows untuk Balena Etcher
# Target: C:\Users\embun\Documents\ARMBIAN\JWS_NEW_VERSION
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_IMG="${SCRIPT_DIR}/output/orangepi_zero3_jws.img"
DEST_WIN_DIR="/mnt/c/Users/embun/Documents/ARMBIAN/JWS_NEW_VERSION"

echo "============================================================"
echo "🚀 DEPLOY IMAGE OS KE WINDOWS (BALENA ETCHER)"
echo "============================================================"
echo "Sumber Image : ${SOURCE_IMG}"
echo "Tujuan Windows: ${DEST_WIN_DIR}"
echo "Path Windows  : C:\\Users\\embun\\Documents\\ARMBIAN\\JWS_NEW_VERSION"
echo "============================================================"

# 1. Validasi File Sumber
if [ ! -f "${SOURCE_IMG}" ]; then
    echo "❌ Error: File image '${SOURCE_IMG}' tidak ditemukan!"
    echo "   Silakan build image terlebih dahulu dengan: ./scripts/04_create_image.sh"
    exit 1
fi

IMG_SIZE=$(du -h "${SOURCE_IMG}" | cut -f1)
echo "📦 Ukuran Image: ${IMG_SIZE}"

# 2. Validasi & Buat Folder Tujuan di Windows
if [ ! -d "${DEST_WIN_DIR}" ]; then
    echo "📁 Membuat folder tujuan di Windows..."
    mkdir -p "${DEST_WIN_DIR}"
fi

# 3. Salin File Image dengan Progress Bar
echo ""
echo "⏳ Memulai penyalinan image mentah (1.5GB) ke Windows (mohon tunggu)..."
rsync -ah --progress "${SOURCE_IMG}" "${DEST_WIN_DIR}/orangepi_zero3_jws.img"

# 4. Buat File Kompresi .zip Ringan (~450MB) untuk Balena Etcher
echo ""
echo "📦 Mengompres image menjadi format .zip super ringan untuk Balena Etcher..."
(cd "${SCRIPT_DIR}/output" && zip -q -1 "${DEST_WIN_DIR}/orangepi_zero3_jws.zip" "orangepi_zero3_jws.img") || true
if [ -f "${DEST_WIN_DIR}/orangepi_zero3_jws.zip" ]; then
    ZIP_SIZE=$(du -h "${DEST_WIN_DIR}/orangepi_zero3_jws.zip" | cut -f1)
    echo "✅ Berhasil membuat file zip ringan: ${ZIP_SIZE}"
fi

# 5. Salin Berkas Partisi BOOT ke Folder Terpisah (Bisa di-copy langsung via Windows Explorer)
echo ""
echo "📁 Menyalin berkas partisi BOOT (Kernel, DTB, boot.scr, extlinux, splash) ke Windows..."
BOOT_COPY_DIR="${DEST_WIN_DIR}/BOOT_FILES_DIRECT_COPY"
rm -rf "${BOOT_COPY_DIR}"
mkdir -p "${BOOT_COPY_DIR}"
cp -r "${SCRIPT_DIR}/build/staging_boot"/* "${BOOT_COPY_DIR}/"

# 6. Buat File Panduan Burning Balena Etcher di Windows
cat << 'EOF' > "${DEST_WIN_DIR}/CARA_BURN_BALENA_ETCHER.txt"
================================================================================
PANDUAN FLASHING / BURNING IMAGE OS ORANGE PI ZERO 3 (JWS)
================================================================================

Tersedia 2 pilihan file image (pilih salah satu di Balena Etcher / Rufus):
A. orangepi_zero3_jws.img  -> File mentah image 1.5GB (SANGAT RINGAN & CEPAT FLASH!).
B. orangepi_zero3_jws.zip  -> File kompresi super hemat bandwidth (~500MB).

Alternatif Update Cepat (Tanpa Flash Ulang):
Jika SD Card Anda sudah memiliki partisi BOOT (FAT) dan partisi ROOTFS:
Cukup salin seluruh isi folder "BOOT_FILES_DIRECT_COPY" ke dalam partisi SD Card
(Drive BOOT di Windows Explorer) untuk mengganti kernel, DTB, dan boot script!

Langkah Flashing Bersih via Balena Etcher / Rufus:
1. Masukkan MicroSD Card ke Card Reader PC Windows.
2. Buka Balena Etcher (atau Rufus bila Balena Etcher mengalami error sidecar).
3. Pilih "orangepi_zero3_jws.img" (atau .zip).
4. Pilih drive MicroSD Card Anda (minimal 2GB/4GB/8GB).
5. Klik "Flash!" dan tunggu hingga 100% Verified.
6. Lepas MicroSD dan pasang ke Orange Pi Zero 3:
   - Pasang kabel HDMI ke TV/Monitor.
   - Pasang kabel USB Type-C daya 5V 2A-3A.
   - Booting teks HANYA keluar di UART Debug (ttyS0, 115200 8N1).
   - Layar HDMI murni menampilkan splash animasi dan langsung masuk ke aplikasi JWS.

Spesifikasi & Optimasi:
- Kernel : Linux 6.1.31 (Driver Display Engine DE33 & HDMI PHY aktif fisik)
- RAM    : Dioptimasi khusus RAM 512MB (cma=64M + 256MB ZRAM Swap aktif)
- Display: KMS/DRM murni (bebas X11/Desktop bloatware)
- Akses  : SSH aktif (user: jws, pass: jws), UART auto-login jws.
================================================================================
EOF

echo ""
echo "============================================================"
echo "✅ BERHASIL DI-DEPLOY KE WINDOWS!"
echo "============================================================"
echo "Lokasi File di Windows:"
echo "👉 C:\\Users\\embun\\Documents\\ARMBIAN\\JWS_NEW_VERSION\\orangepi_zero3_jws.img (1.5GB Mentah)"
echo "👉 C:\\Users\\embun\\Documents\\ARMBIAN\\JWS_NEW_VERSION\\orangepi_zero3_jws.zip (~500MB)"
echo "👉 C:\\Users\\embun\\Documents\\ARMBIAN\\JWS_NEW_VERSION\\BOOT_FILES_DIRECT_COPY\\"
echo "👉 C:\\Users\\embun\\Documents\\ARMBIAN\\JWS_NEW_VERSION\\CARA_BURN_BALENA_ETCHER.txt"
echo "============================================================"
