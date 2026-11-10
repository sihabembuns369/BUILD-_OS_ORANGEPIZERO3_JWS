#!/usr/bin/env bash
# scripts/03_build_rootfs.sh
# Membangun Debian minimalis rootfs arm64 dengan debootstrap, paket, dan overlay

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_environment.sh"

echo "=========================================================="
echo " [3/4] Membangun Debian Rootfs (${DEBIAN_SUITE} arm64)"
echo "=========================================================="

if [ "$EUID" -ne 0 ]; then
    echo "Skrip ini memerlukan hak akses root (sudo) untuk menjalankan debootstrap dan chroot."
    exec sudo -E bash "$0" "$@"
fi

mkdir -p "${ROOTFS_DIR}"

# 1. Debootstrap tahap pertama & kedua
if [ ! -f "${ROOTFS_DIR}/bin/bash" ]; then
    echo "==> Menjalankan debootstrap untuk Debian ${DEBIAN_SUITE}..."
    debootstrap --arch=arm64 \
        --foreign \
        --include=systemd,systemd-sysv,udev,dbus,locales,ca-certificates,sudo,bash-completion,kmod \
        "${DEBIAN_SUITE}" "${ROOTFS_DIR}" http://deb.debian.org/debian

    # Salin binary qemu-aarch64-static untuk emulasi chroot
    cp /usr/bin/qemu-aarch64-static "${ROOTFS_DIR}/usr/bin/"

    echo "==> Menjalankan debootstrap second-stage di chroot..."
    chroot "${ROOTFS_DIR}" /debootstrap/debootstrap --second-stage
fi

# Pastikan qemu-aarch64-static tersedia di rootfs
cp -f /usr/bin/qemu-aarch64-static "${ROOTFS_DIR}/usr/bin/" || true

# Setup mount chroot
cleanup() {
    echo "==> Membersihkan mount..."
    umount -l "${ROOTFS_DIR}/proc" 2>/dev/null || true
    umount -l "${ROOTFS_DIR}/sys" 2>/dev/null || true
    umount -l "${ROOTFS_DIR}/dev/pts" 2>/dev/null || true
    umount -l "${ROOTFS_DIR}/dev" 2>/dev/null || true
}
trap cleanup EXIT

mount -t proc /proc "${ROOTFS_DIR}/proc"
mount -t sysfs /sys "${ROOTFS_DIR}/sys"
mount --bind /dev "${ROOTFS_DIR}/dev"
mount --bind /dev/pts "${ROOTFS_DIR}/dev/pts"

# Salin resolv.conf untuk akses internet chroot
cp -L /etc/resolv.conf "${ROOTFS_DIR}/etc/resolv.conf"

echo "==> Mengonfigurasi apt mirror dan instalasi paket..."
cat <<EOF > "${ROOTFS_DIR}/etc/apt/sources.list"
deb http://deb.debian.org/debian ${DEBIAN_SUITE} main contrib non-free non-free-firmware
deb http://deb.debian.org/debian ${DEBIAN_SUITE}-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security ${DEBIAN_SUITE}-security main contrib non-free non-free-firmware
EOF

# Jalankan instalasi paket di dalam chroot
chroot "${ROOTFS_DIR}" /bin/bash -e << 'CHROOT_EOF'
export DEBIAN_FRONTEND=noninteractive
apt-get update

# Paket Hardware, Audio, IR, WiFi, Bluetooth, Plymouth, SDL2, dan SSH
apt-get install -y --no-install-recommends \
    linux-base \
    initramfs-tools \
    openssh-server \
    avahi-daemon \
    libnss-mdns \
    alsa-utils \
    libasound2 \
    ir-keytable \
    wpasupplicant \
    wireless-tools \
    rfkill \
    bluez \
    plymouth \
    plymouth-themes \
    ffmpeg \
    libdrm2 \
    libgbm1 \
    libgl1-mesa-dri \
    libegl1-mesa \
    libgles2-mesa \
    libsdl2-2.0-0 \
    libsdl2-image-2.0-0 \
    libsdl2-ttf-2.0-0 \
    curl \
    iproute2 \
    iputils-ping \
    dosfstools \
    e2fsprogs \
    parted \
    nano

# Konfigurasi SSH Server Hardening
sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Hapus host keys bawaan (agar digenerate secara unik saat first boot via ssh-setup)
rm -f /etc/ssh/ssh_host_*

# Buat user jws non-root dengan sudo
if ! id -u jws >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo,audio,video,render,input,dialout jws
    # Atur password sementara yang wajib diganti atau disiapkan sudo tanpa password
    echo "jws:jws" | chpasswd
    echo "jws ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/010_jws-nopasswd
    chmod 440 /etc/sudoers.d/010_jws-nopasswd
fi

# Atur Locale & Timezone
echo "Asia/Jakarta" > /etc/timezone
ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime || true

# Atur Hostname awal
echo "jws-pi" > /etc/hostname

# Konfigurasi Network (systemd-networkd & DHCP)
cat <<EOF > /etc/systemd/network/20-wired.network
[Match]
Name=eth0 en* end*

[Network]
DHCP=yes
EOF

systemctl enable systemd-networkd || true
systemctl enable systemd-resolved || true
systemctl enable ssh || true
systemctl enable avahi-daemon || true

# Aktifkan serial-getty pada ttyS0 dan getty pada tty2
systemctl enable serial-getty@ttyS0.service || true
systemctl enable getty@tty2.service || true

# Pembersihan cache apt
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
CHROOT_EOF

# 2. Pasang modul kernel yang telah dikompilasi jika tersedia
if [ -d "${OUTPUT_DIR}/modules_install/lib/modules" ]; then
    echo "==> Menyalin modul kernel ke rootfs..."
    mkdir -p "${ROOTFS_DIR}/lib/modules"
    cp -r "${OUTPUT_DIR}/modules_install/lib/modules/"* "${ROOTFS_DIR}/lib/modules/"
    
    # Jalankan depmod di chroot untuk setiap versi kernel terpasang
    for KVER in $(ls "${ROOTFS_DIR}/lib/modules"); do
        chroot "${ROOTFS_DIR}" depmod -a "${KVER}" || true
    done
fi

# 3. Salin overlay file ke rootfs
echo "==> Menerapkan overlay sistem..."
cp -rv "${ROOT_DIR}/overlay/"* "${ROOTFS_DIR}/"

# Salin script gif2splash ke /usr/local/bin di rootfs
cp -v "${ROOT_DIR}/tools/gif2splash.sh" "${ROOTFS_DIR}/usr/local/bin/"
chmod +x "${ROOTFS_DIR}/usr/local/bin/"*

# Salin aset default ke direktori tema
mkdir -p "${ROOTFS_DIR}/usr/share/plymouth/themes/jws-animated"
cp -v "${ROOT_DIR}/default_assets/logo.png" "${ROOTFS_DIR}/usr/share/plymouth/themes/jws-animated/default_logo.png"
cp -v "${ROOT_DIR}/default_assets/logo.png" "${ROOTFS_DIR}/usr/share/plymouth/themes/jws-animated/splash.png"

# Aktifkan systemd units yang ada di overlay
chroot "${ROOTFS_DIR}" /bin/bash -e << 'CHROOT_EOF'
systemctl enable splash-apply.service || true
systemctl enable system-apply.service || true
systemctl enable ssh-setup.service || true
systemctl enable jws.service || true

# Atur default plymouth theme
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    plymouth-set-default-theme -R jws-animated || true
fi
CHROOT_EOF

echo "=========================================================="
echo " SUKSES: Rootfs Debian ${DEBIAN_SUITE} siap di ${ROOTFS_DIR}"
echo "=========================================================="
