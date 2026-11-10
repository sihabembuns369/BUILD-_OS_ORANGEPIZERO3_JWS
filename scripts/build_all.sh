#!/usr/bin/env bash
# scripts/build_all.sh
# Master build script untuk OS Orange Pi Zero 3 JWS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "##########################################################"
echo "  MEMULAI PROSES BUILD LINUX ORANGE PI ZERO 3 (JWS)      "
echo "##########################################################"

"${SCRIPT_DIR}/01_build_u-boot.sh"
"${SCRIPT_DIR}/02_build_kernel.sh"
"${SCRIPT_DIR}/03_build_rootfs.sh"
"${SCRIPT_DIR}/04_create_image.sh"

echo "##########################################################"
echo "  SELURUH TAHAPAN BUILD TELAH BERHASIL DISELESAIKAN!      "
echo "##########################################################"
