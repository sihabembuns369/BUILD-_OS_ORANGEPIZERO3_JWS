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
echo "⏳ [1/3] Menyalin file image mentah (${IMG_SIZE}) ke Windows..."
if command -v pv >/dev/null 2>&1; then
    pv -p -t -e -r -b "${SOURCE_IMG}" > "${DEST_WIN_DIR}/orangepi_zero3_jws.img"
else
    rsync -ah --info=progress2 "${SOURCE_IMG}" "${DEST_WIN_DIR}/orangepi_zero3_jws.img"
fi

# 4. Buat File Kompresi .zip Ringan (~500MB) untuk Balena Etcher
echo ""
echo "📦 [2/3] Mengompres image menjadi format .zip ringan untuk Balena Etcher..."
python3 -c "
import sys, os, time, zipfile

src = '${SOURCE_IMG}'
dst = '${DEST_WIN_DIR}/orangepi_zero3_jws.zip'
total = os.path.getsize(src)
start_time = time.time()
chunk_size = 4 * 1024 * 1024  # 4MB chunks
written = 0

with open(src, 'rb') as f_in, zipfile.ZipFile(dst, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=1) as z_out:
    zinfo = zipfile.ZipInfo(filename='orangepi_zero3_jws.img', date_time=time.localtime(time.time())[:6])
    zinfo.compress_type = zipfile.ZIP_DEFLATED
    zinfo.external_attr = 0o644 << 16
    with z_out.open(zinfo, 'w') as f_out:
        while True:
            chunk = f_in.read(chunk_size)
            if not chunk:
                break
            f_out.write(chunk)
            written += len(chunk)
            pct = (written / total) * 100
            elapsed = time.time() - start_time
            speed = (written / (1024 * 1024)) / elapsed if elapsed > 0 else 0
            eta = ((total - written) / (1024 * 1024)) / speed if speed > 0 else 0
            bar_len = 35
            filled = int(round(bar_len * written / float(total)))
            bar = '=' * filled + '>' if filled < bar_len else '=' * bar_len
            bar = bar[:bar_len]
            sys.stdout.write(f'\r📦 [{bar:<{bar_len}}] {pct:5.1f}% | {written/(1024*1024):.0f}/{total/(1024*1024):.0f} MB | {speed:5.1f} MB/s | ETA: {int(eta):2d}s')
            sys.stdout.flush()

elapsed = time.time() - start_time
zip_sz = os.path.getsize(dst) / (1024 * 1024)
print(f'\n✅ Selesai dalam {elapsed:.1f}s | Ukuran zip: {zip_sz:.1f} MB')
"

# 5. Salin Berkas Partisi BOOT ke Folder Terpisah (Bisa di-copy langsung via Windows Explorer)
echo ""
echo "📁 [3/3] Menyalin berkas partisi BOOT (Kernel, DTB, boot.scr, extlinux, splash) ke Windows..."
BOOT_COPY_DIR="${DEST_WIN_DIR}/BOOT_FILES_DIRECT_COPY"
rm -rf "${BOOT_COPY_DIR}"
mkdir -p "${BOOT_COPY_DIR}"
rsync -ah --info=progress2 "${SCRIPT_DIR}/build/staging_boot/" "${BOOT_COPY_DIR}/"

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
