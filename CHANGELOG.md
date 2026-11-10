# CHANGELOG

## [2026-11-10] Milestone 3: Integrasi Sistem Lengkap, Verifikasi QEMU, dan Validasi Kriteria Lulus
- Apa yang diubah:
  - Pembuatan dan provisioning Rootfs Debian 12 (Bookworm) ARM64 minimalis dengan kernel modules 6.6.162, depmod, SDL2 runtime, alsa-utils, bluez, wpa_supplicant, openssh-server, plymouth, dan ffmpeg.
  - Perbaikan dan optimasi skrip `overlay/usr/local/bin/splash-apply`: implementasi bash arithmetic murni untuk konversi hex ke float RGB, inline comment stripping, dan manajemen cache SHA-256 yang reliabel.
  - Perbaikan skrip `overlay/usr/local/bin/system-apply`: pencegahan circular dependency / ordering cycle dengan `ssh.service`.
  - Pembuatan disk image siap burn `output/orangepi_zero3_jws.img` (3.0 GB) dengan MBR partition table (Partisi 1 FAT32 BOOT 128MB, Partisi 2 EXT4 ROOTFS 2.9GB, U-Boot SPL di offset 8KB).
  - Pengujian simulasi sistem penuh di QEMU virt ARM64 mencakup boot, console login UART, SSH server, autostart aplikasi JWS, dan 5 variasi konfigurasi splash screen beserta verifikasi fallback & batas aman.
- Alasan: Memenuhi seluruh kriteria fungsional dan kriteria lulus uji yang diwajibkan dalam AGENTS.md.
- File/komponen terdampak: `overlay/*`, `scripts/*`, `configs/*`, `runQemu`, `CHANGELOG.md`, `README.md`, `HowTo.md`.
- Hasil uji (QEMU / board fisik):
  - [x] Boot QEMU stabil tanpa kernel panic sampai login prompt serial UART `jws-pi login:`.
  - [x] Login serial UART berhasil menggunakan user non-root `jws`.
  - [x] Autostart `jws.service` (SDL2 Kiosk) status `active (running)`.
  - [x] `ssh.service` aktif otomatis saat boot; login via SSH port 22220 berhasil dengan user `jws`, `PermitRootLogin no` aktif, dan SSH host keys dibuat unik saat boot pertama oleh `ssh-setup.service`.
  - [x] Variasi Splash 1 (`MODE=image`): Berhasil dimuat dan dikonfigurasi ke Plymouth.
  - [x] Variasi Splash 2 (`MODE=frames`, `LOOP=no`): 10 frame dimuat, parameter `loop_mode = 0` terverifikasi.
  - [x] Variasi Splash 3 (`MODE=gif`, `FPS=24`, `LOOP=yes`): Konversi otomatis 24 frame via ffmpeg berhasil, parameter `loop_mode = 1`, `target_fps = 24`.
  - [x] Variasi Splash 4 (`ENABLED=no`): Plymouth theme dialihkan dan dinonaktifkan bersih tanpa error.
  - [x] Variasi Splash 5 (Warna/Skala/Posisi custom): Nilai hex `#102030` dikonversi presisi menjadi float RGB `(0.062, 0.125, 0.188)`, skala `stretch`, posisi `top`.
  - [x] Cache SHA-256 teruji instan: Reboot/apply kedua tanpa perubahan media hanya memakan waktu 1 detik (`cache valid`).
  - [x] Fallback & Batas Aman teruji: Uji file hilang (`nonexistent.png`) langsung memicu fallback otomatis ke logo default statis tanpa boot gagal dan tercatat di log journalctl.
  - [x] Waktu boot tercatat: ~12 detik hingga multi-user target pada cache hit.
  - [x] Ukuran image: 3.0 GB uncompressed (dapat dikompresi xz menjadi ~450 MB untuk distribusi).
  - [!] Daftar item yang wajib diuji di board fisik: GPIO IR remote (VS1838B pada PA2/PL9), HDMI output fisik (resolusi TV/monitor & EDID), audio ALSA analog fisik, WiFi/BT CDW-20U5622 on-board, akselerasi GPU Mali Panfrost pada board nyata.
- Commit / tag: `feat(system): validasi seluruh kriteria uji qemu, splash dinamis, dan image build`


## [2026-11-10] Milestone 1 & 2: Sukses Kompilasi U-Boot dan Linux Kernel Mainline ARM64
- Apa yang diubah:
  - ARM Trusted Firmware (BL31) untuk platform `sun50i_h616` berhasil dikompilasi.
  - Das U-Boot (`orangepi_zero3_defconfig`) berhasil dikompilasi menghasilkan `u-boot-sunxi-with-spl.bin`.
  - Kernel Linux Mainline v6.6.162 (ARM64) berhasil dikompilasi menghasilkan `Image`, device tree blob `sun50i-h618-orangepi-zero3.dtb`, modul-modul driver (DRM Allwinner, HDMI, ALSA audio, IR remote, WiFi/BT, Virtio QEMU), dan konfigurasi kernel disimpan ke `configs/kernel_arm64_defconfig`.
- Alasan: Menyediakan bootloader dan kernel stabil yang mendukung hardware Allwinner H618 serta kompatibel dengan simulasi virtual QEMU.
- File/komponen terdampak: `configs/kernel_arm64_defconfig`, `output/u-boot-sunxi-with-spl.bin`, `output/Image`, `output/sun50i-h618-orangepi-zero3.dtb`, `CHANGELOG.md`.
- Hasil uji (QEMU / board fisik):
  - U-Boot SPL siap dipasang di offset 8KB.
  - Kernel Image (6.6.162) dan DTB siap dimuat oleh bootloader/QEMU.
- Commit / tag: `build(kernel): kompilasi kernel mainline arm64 v6.6 dan u-boot sunxi spl`

## [2026-11-10] Implementasi Skrip Build Modular, Plymouth Theme Dinamis, dan Konfigurasi Sistem
- Apa yang diubah:
  - Pembuatan skrip build modular: `scripts/00_environment.sh`, `scripts/01_build_u-boot.sh`, `scripts/02_build_kernel.sh`, `scripts/03_build_rootfs.sh`, `scripts/04_create_image.sh`, dan `scripts/build_all.sh`.
  - Pembuatan tema dinamis Plymouth `jws-animated` yang mendukung 3 mode (statis, PNG frame sequences, dan konversi animasi GIF).
  - Pembuatan skrip `overlay/usr/local/bin/splash-apply` dengan validasi batas aman (max 60 frame, max 20MB, subsampling, fallback logo statis) dan hash caching SHA-256.
  - Pembuatan skrip host `tools/gif2splash.sh` untuk konversi manual GIF di PC.
  - Pembuatan skrip `system-apply`, `ssh-setup`, serta systemd units (`splash-apply.service`, `system-apply.service`, `ssh-setup.service`, `jws.service`).
  - Pembuatan template konfigurasi `/boot/splash.conf.example`, `/boot/system.conf.example`, dan `/boot/wifi.conf.example`.
  - Pembuatan aset default ringan `logo.png` dan animasi `boot.gif` (< 35 KB).
  - Pembaruan skrip simulasi `runQemu` dan panduan komprehensif `HowTo.md`.
- Alasan: Memenuhi seluruh spesifikasi teknis dan aturan operasional di AGENTS.md.
- File/komponen terdampak: `scripts/*`, `overlay/*`, `tools/*`, `configs/*`, `default_assets/*`, `runQemu`, `HowTo.md`, `CHANGELOG.md`.
- Hasil uji (QEMU / board fisik):
  - Uji `tools/gif2splash.sh` dengan `default_assets/boot.gif`: Berhasil mengekstrak 24 frame PNG dengan target resolusi tanpa distorsi.
  - Pengujian simulasi sistem penuh akan dilanjutkan pada tahap runQemu.
- Commit / tag: `feat(core): implementasi skrip build, tema splash dinamis, dan service konfigurasi`

## [2026-11-10] Inisialisasi Proyek dan Setup Struktur Dasar
- Apa yang diubah: Inisialisasi git repository, konfigurasi remote origin, penambahan `.gitignore`, `README.md`, dan baseline `CHANGELOG.md`.
- Alasan: Mempersiapkan repository kerja terstruktur sesuai spesifikasi AGENTS.md.
- File/komponen terdampak: `.gitignore`, `README.md`, `CHANGELOG.md`.
- Hasil uji (QEMU / board fisik): N/A (tahap inisialisasi).
- Commit / tag: `chore(init): inisialisasi repository dan setup struktur proyek`
