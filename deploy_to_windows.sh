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
echo "⏳ Memulai penyalinan image ke Windows (mohon tunggu)..."
rsync -ah --progress "${SOURCE_IMG}" "${DEST_WIN_DIR}/orangepi_zero3_jws.img"

# 4. Buat File Panduan Burning Balena Etcher di Windows
cat << 'EOF' > "${DEST_WIN_DIR}/CARA_BURN_BALENA_ETCHER.txt"
================================================================================
PANDUAN FLASHING / BURNING IMAGE OS ORANGE PI ZERO 3 (JWS)
================================================================================

1. Buka aplikasi Balena Etcher di Windows.
2. Klik tombol "Flash from file".
3. Pilih file image:
   orangepi_zero3_jws.img
   (Lokasi: C:\Users\embun\Documents\ARMBIAN\JWS_NEW_VERSION\orangepi_zero3_jws.img)
4. Klik "Select target" -> Pilih MicroSD Card Anda (rekomendasi Class 10 / U3, minimal 8GB).
5. Klik "Flash!" dan tunggu sampai proses flashing serta verifikasi selesai.
6. Masukkan MicroSD ke slot Orange Pi Zero 3:
   - Hubungkan kabel HDMI ke TV/Monitor.
   - Hubungkan adaptor daya USB Type-C (5V 3A disarankan).
   - Layar akan langsung menampilkan boot splash animasi/gambar dan aplikasi
     Jadwal Sholat Digital akan berjalan otomatis fullscreen.

Akses Remote & Debug:
- SSH: ssh jws@<IP_ORANGEPI> atau ssh jws@jws-pi.local (Password: jws)
- UART Debug: Pin Header UART0 (ttyS0, Baudrate 115200 8N1)
- Web Remote: Buka browser di HP/Laptop: http://<IP_ORANGEPI>:8080
================================================================================
EOF

echo ""
echo "============================================================"
echo "✅ BERHASIL DI-DEPLOY KE WINDOWS!"
echo "============================================================"
echo "Lokasi File di Windows:"
echo "👉 C:\\Users\\embun\\Documents\\ARMBIAN\\JWS_NEW_VERSION\\orangepi_zero3_jws.img"
echo "👉 C:\\Users\\embun\\Documents\\ARMBIAN\\JWS_NEW_VERSION\\CARA_BURN_BALENA_ETCHER.txt"
echo ""
echo "Silakan buka Balena Etcher di Windows dan langsung flash file tersebut ke MicroSD!"
echo "============================================================"
