# OS Embedded Linux - Orange Pi Zero 3 (Allwinner H618) untuk JWS

Distribusi Linux Debian minimalis teroptimasi untuk Orange Pi Zero 3 (Allwinner H618) yang dikhususkan untuk menjalankan aplikasi Jadwal Waktu Salat (JWS) berbasis SDL2 + Dear ImGui.

## Fitur Utama
1. **Dynamic Splash Screen**: Mendukung 3 mode tampilan (statis, urutan frame PNG, dan animasi GIF dengan konversi cache otomatis menggunakan Plymouth script theme).
2. **Autostart Aplikasi JWS**: Menjalankan aplikasi SDL2 secara fullscreen via systemd service dengan transisi mulus dari splash screen.
3. **Dual Output Konsol**: UART Debug (`ttyS0`, 115200 8N1) dan HDMI (`tty1`) aktif bersamaan. Log boot penuh di UART, HDMI bersih dengan splash & aplikasi.
4. **Remote Access & Hardening**: OpenSSH server aktif saat boot, regenerasi host key unik pada first-boot, non-root user (`jws`) dengan akses sudo, konfigurasi via `/boot/system.conf`.
5. **Dukungan Hardware Lengkap**: GPIO IR remote, ALSA audio, WiFi/Bluetooth (driver & firmware), HDMI DRM/KMS, dan Ethernet.

## Struktur Direktori
- `scripts/`: Skrip otomasi build bootloader, kernel, rootfs, dan packaging image.
- `configs/`: File konfigurasi kernel, u-boot, dan template sistem.
- `tools/`: Utility pendukung seperti konversi manual GIF (`tools/gif2splash.sh`).
- `overlay/`: File rootfs overlay (systemd service, udev rules, plymouth themes).
- `HowTo.md`: Panduan lengkap proses build, konfigurasi, dan troubleshooting.
- `runQemu`: Skrip untuk simulasi dan verifikasi OS di QEMU aarch64.

## Petunjuk Singkat
Rujuk ke [HowTo.md](file:///home/riski/JWS_ORANGEPI_BUILDLINUX/HowTo.md) untuk langkah-langkah detail membangun sistem.
