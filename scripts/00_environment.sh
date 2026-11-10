#!/usr/bin/env bash
# scripts/00_environment.sh
# Konfigurasi variabel dan environment build OS Orange Pi Zero 3 (H618)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export NPROC=$(nproc)

export BUILD_DIR="${ROOT_DIR}/build"
export OUTPUT_DIR="${ROOT_DIR}/output"
export ROOTFS_DIR="${BUILD_DIR}/rootfs"
export DOWNLOAD_DIR="${BUILD_DIR}/sources"

export ATF_DIR="${BUILD_DIR}/arm-trusted-firmware"
export UBOOT_DIR="${BUILD_DIR}/u-boot"
export KERNEL_DIR="${BUILD_DIR}/linux"

export ATF_BRANCH="master"
export UBOOT_BRANCH="master"
# Kernel v6.6 LTS atau v6.1 LTS adalah versi paling stabil untuk sun50i-h616/h618
export KERNEL_BRANCH="linux-6.6.y"

export DEBIAN_SUITE="bookworm"
export TARGET_HOSTNAME="jws-pi"
export DEFAULT_USER="jws"

mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}" "${DOWNLOAD_DIR}"
