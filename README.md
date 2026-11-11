# OS Embedded Linux - Orange Pi Zero 3 (Allwinner H618) untuk JWS

Distribusi Linux Debian minimalis berbasis arm64 yang teroptimasi untuk **Orange Pi Zero 3 (Allwinner H618)**, dirancang khusus untuk menjalankan aplikasi **Jadwal Waktu Salat (JWS)** berbasis SDL2 + Dear ImGui secara fullscreen, otomatis, dan andal.

---

## Fitur Utama

1. **Dynamic Splash Screen (Plymouth Script)**:
   - Mendukung 3 mode tampilan: gambar statis (`image`), urutan frame PNG (`frames`), atau animasi GIF (`gif`).
   - Konversi GIF otomatis oleh `splash-apply` dengan validasi batas aman (maks 60 frame, subsampling, resize 720p, total < 20MB) dan SHA-256 hash cache (boot berikutnya instan).
   - Fallback otomatis ke logo default jika media hilang, format rusak, atau konfigurasi salah.
2. **Autostart Aplikasi JWS**:
   - Berjalan otomatis saat boot via `jws.service` (systemd), restart otomatis jika crash.
   - Transisi bersih dari Plymouth ke SDL2 DRM/KMS tanpa kedipan layar hitam atau konflik DRM master.
3. **Dual Output Konsol**:
   - UART Debug (`ttyS0`, 115200 8N1) menampilkan log boot penuh U-Boot, kernel, dan systemd.
   - HDMI (`tty1`) bersih menutupi log boot, menampilkan splash screen dan langsung transisi ke UI aplikasi.
   - Login konsol darurat tersedia di `tty2` via keyboard HDMI.
4. **Remote Access & Hardening**:
   - OpenSSH server aktif saat boot (`ssh.service`), port default 22.
   - User non-root `jws` dengan hak akses `sudo`, `PermitRootLogin no`.
   - Host key unik digenerate pada first-boot oleh `ssh-setup.service`.
   - Konfigurasi headless SSH & hostname via `/boot/system.conf`, WiFi via `/boot/wifi.conf`, dan public key via `/boot/authorized_keys`.
5. **Dukungan Hardware Lengkap**:
   - GPIO Infra Red (`gpio-ir` / `rc-core` / `lirc`) untuk remote control.
   - Audio ALSA aktif untuk azan dan alarm salat.
   - Driver & firmware WiFi/Bluetooth on-board aktif saat boot.
   - Driver DRM/KMS Allwinner sun4i dan Panfrost Mali G31 MP2 aktif.

---

## Panduan Build

Untuk panduan lengkap dan detail spesifikasi langkah per langkah, silakan baca [HowTo.md](HowTo.md).

### Prasyarat
Sistem host berbasis Linux (Debian/Ubuntu x86_64) dengan paket build essentials, gcc aarch64 cross-compiler, bison, flex, libssl-dev, swig, python3, ffmpeg, imagemagick, qemu-user-static, dan debootstrap.

### Menjalankan Build
Cukup jalankan satu perintah:
```bash
bash scripts/build_all.sh
```
Hasil build akhir berupa file image disk siap burn tersimpan di `output/orangepi_zero3_jws.img`.

---

## Menjalankan Simulasi di QEMU

Untuk menguji booting, konsol serial, SSH server, autostart aplikasi JWS, dan tema splash di PC tanpa board fisik:

```bash
./runQemu
```

- **Serial Console**: Tampil langsung di terminal (`-nographic` / UART virtual). Login dengan user `jws`, password `jws`.
- **SSH Port Forwarding**: Akses SSH dari host terminal lain:
  ```bash
  ssh -p 22220 jws@127.0.0.1
  ```
- **Keluar dari QEMU**: Tekan kombinasi tombol `Ctrl+A` lalu tekan `X`, atau jalankan `sudo poweroff` di dalam konsol VM.

---

## Cara Mengganti Splash Screen & Boot Logo (Armbian / Anbernic style)

Sistem menggunakan konsep **Boot Logo statis bersih ala Armbian** secara default, dan mendukung U-Boot native splash bitmap serta animasi:

1. **Boot Logo Statis (Default ala Armbian)**:
   - Cukup ganti file gambar di `/boot/splash/logo.png` (bisa PNG atau JPG).
   - Layar HDMI akan menampilkan logo tenang di tengah latar hitam bersih tanpa teks.
2. **U-Boot Splash Screen Paling Awal (`splash.bmp`)**:
   - Letakkan file bitmap 24-bit BMP di `/boot/splash.bmp` (resolusi disarankan 1280x720).
   - Tampil seketika dari U-Boot saat board pertama kali dinyalakan.
3. **Mode Animasi (Frames / GIF)**:
   - Anda dapat mengaktifkan animasi kembali kapan saja melalui `/boot/splash.conf`:
     ```ini
     MODE=gif
     GIF=/boot/splash/boot.gif
     FPS=15
     LOOP=yes
     ```
3. **Kustomisasi Tampilan**:
   ```ini
   BACKGROUND_COLOR=#000000
   IMAGE_SCALE=fit
   POSITION=center
   TEXT=Memuat jadwal salat...
   TEXT_COLOR=#FFFFFF
   MIN_DURATION=3
   ```
4. Simpan file dan boot Orange Pi Zero 3. Pada boot pertama setelah file diganti, `splash-apply` akan mengonversi dan menyimpan cache hash SHA-256. Reboot berikutnya akan membaca cache dan booting cepat.

> **Tool Konversi di PC (Opsional)**:
> Anda juga dapat mengonversi file GIF di PC host sebelum disalin ke SD card:
> ```bash
> ./tools/gif2splash.sh animasi.gif output_frames/ 60 1280x720
> ```

---

## Cara Terhubung lewat UART Debug dan SSH

### 1. UART Debug (Serial Console)
- **Pinout Header Orange Pi Zero 3 (3-pin debug header)**:
  - **TX** (Board) -> Hubungkan ke **RX** USB-to-UART Adapter.
  - **RX** (Board) -> Hubungkan ke **TX** USB-to-UART Adapter.
  - **GND** (Board) -> Hubungkan ke **GND** USB-to-UART Adapter.
  > **PENTING**: Gunakan level logika 3.3V TTL (bukan RS232 standard / 5V).
- **Perintah Koneksi**:
  ```bash
  picocom -b 115200 /dev/ttyUSB0
  # atau
  minicom -D /dev/ttyUSB0 -b 115200
  ```
  Login prompt: `jws-pi login:`. Masukkan user `jws`, password `jws`.

### 2. Remote SSH
- Pastikan Orange Pi Zero 3 terhubung ke jaringan via kabel Ethernet atau WiFi (konfigurasi via `/boot/wifi.conf`).
- Hubungkan via terminal host:
  ```bash
  ssh jws@jws-pi.local
  # atau gunakan IP perangkat
  ssh jws@192.168.1.xxx
  ```
- Password autentikasi dan SSH port dapat dikonfigurasi melalui `/boot/system.conf`.
- Kunci publik SSH dapat diletakkan di `/boot/authorized_keys` agar disalin otomatis saat boot.

---

## Struktur File Repositori

```
├── configs/
│   ├── kernel_arm64_defconfig
│   ├── orangepi_zero3_defconfig
│   ├── splash.conf.example
│   ├── system.conf.example
│   └── wifi.conf.example
├── default_assets/
│   ├── boot.gif
│   ├── default_logo.png
│   └── splash.bmp
├── overlay/
│   ├── etc/systemd/system/
│   │   ├── jws.service
│   │   ├── splash-apply.service
│   │   ├── ssh-setup.service
│   │   └── system-apply.service
│   └── usr/
│       ├── local/bin/
│       │   ├── jws-app
│       │   ├── splash-apply
│       │   └── system-apply
│       └── share/plymouth/themes/jws-animated/
├── scripts/
│   ├── 00_environment.sh
│   ├── 01_build_u-boot.sh
│   ├── 02_build_kernel.sh
│   ├── 03_build_rootfs.sh
│   ├── 04_create_image.sh
│   └── build_all.sh
├── tools/
│   └── gif2splash.sh
├── HowTo.md
├── CHANGELOG.md
├── README.md
├── runQemu
└── AGENTS.md
```
