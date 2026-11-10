# CHANGELOG

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
