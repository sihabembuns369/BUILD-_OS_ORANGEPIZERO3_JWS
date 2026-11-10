# Panduan Komprehensif Build OS Linux Orange Pi Zero 3 (Allwinner H618) untuk JWS

Dokumen ini menjelaskan rancangan, kompilasi, dan konfigurasi sistem operasi Debian Linux minimalis untuk Orange Pi Zero 3 (Allwinner H618) yang didedikasikan untuk menjalankan aplikasi Jadwal Waktu Salat (JWS) berbasis SDL2 + Dear ImGui.

---

## 1. Persyaratan Lingkungan Build Host
Gunakan Ubuntu 22.04 LTS / 24.04 LTS atau Debian 12 (bookworm) x86_64:

```bash
sudo apt update
sudo apt install -y build-essential gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
    bison flex libssl-dev bc u-boot-tools qemu-user-static qemu-system-aarch64 \
    debootstrap parted dosfstools e2fsprogs ffmpeg imagemagick git rsync
```

---

## 2. Struktur Proyek
- `scripts/00_environment.sh`: Konfigurasi variabel path, arsitektur, dan toolchain.
- `scripts/01_build_u-boot.sh`: Build ARM Trusted Firmware (BL31) dan Das U-Boot.
- `scripts/02_build_kernel.sh`: Build Linux Kernel Mainline (ARM64) dengan driver DRM, HDMI, ALSA, IR, dan WiFi.
- `scripts/03_build_rootfs.sh`: Debootstrap Debian minimalis arm64 dengan dependensi SDL2, Plymouth, SSH, dan audio.
- `scripts/04_create_image.sh`: Pembuatan partisi disk image (`.img`), instalasi bootloader SPL, kernel, rootfs, dan konfigurasi boot.
- `scripts/build_all.sh`: Menjalankan seluruh proses build secara terotomasi.
- `tools/gif2splash.sh`: Skrip host PC untuk mengonversi GIF ke urutan frame PNG siap pakai.
- `overlay/`: Template service systemd, binary launcher, dan tema dinamis Plymouth.
- `configs/`: File template konfigurasi `/boot/splash.conf.example`, `/boot/system.conf.example`, dan `/boot/wifi.conf.example`.
- `runQemu`: Skrip pengujian simulasi sistem pada QEMU virtual machine.

---

## 3. Kompilasi Komponen

### A. Bootloader (ATF BL31 + Das U-Boot)
Board Orange Pi Zero 3 menggunakan SoC Allwinner H618 (keluarga sun50i_h616).
1. **ARM Trusted Firmware (ATF)**:
   ```bash
   git clone --depth 1 https://github.com/ARM-software/arm-trusted-firmware.git
   cd arm-trusted-firmware
   make CROSS_COMPILE=aarch64-linux-gnu- PLAT=sun50i_h616 DEBUG=1 bl31
   ```
2. **U-Boot**:
   ```bash
   git clone --depth 1 https://github.com/u-boot/u-boot.git
   cd u-boot
   export BL31=../arm-trusted-firmware/build/sun50i_h616/debug/bl31.bin
   make CROSS_COMPILE=aarch64-linux-gnu- orangepi_zero3_defconfig
   make CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)
   ```
   *Hasil*: `u-boot-sunxi-with-spl.bin` (ditulis ke offset 8KB pada SD card/image).

### B. Linux Kernel Mainline (ARM64)
Menggunakan Linux Kernel stable (v6.6 LTS) yang telah memiliki dukungan upstream Allwinner H616/H618.
- Konfigurasi esensial:
  - **Display / DRM**: `CONFIG_DRM_SUN4I=y`, `CONFIG_DRM_SUN8I_MIXER=y`, `CONFIG_DRM_SUN4I_HDMI=y`, `CONFIG_DRM_PANFROST=y`, `CONFIG_FRAMEBUFFER_CONSOLE=y`.
  - **Serial Console**: `CONFIG_SERIAL_8250_SUNXI=y`, `CONFIG_SERIAL_8250_CONSOLE=y`.
  - **IR Remote**: `CONFIG_RC_CORE=y`, `CONFIG_LIRC=y`, `CONFIG_IR_GPIO_CIR=m`, `CONFIG_IR_SUNXI=m`.
  - **Audio**: `CONFIG_SND_SOC=y`, `CONFIG_SND_SUN4I_CODEC=y`, `CONFIG_SND_SUN8I_CODEC=y`.
  - **Virtio QEMU**: `CONFIG_VIRTIO=y`, `CONFIG_DRM_VIRTIO_GPU=y`, `CONFIG_VIRTIO_NET=y`.
```bash
./scripts/02_build_kernel.sh
```

---

## 4. Display Stack & Splash Screen Dinamis

### A. Pilihan Display Stack untuk SDL2
- **Pilihan**: **Direct DRM/KMS (`SDL_VIDEODRIVER=kmsdrm`)**.
- **Alasan**:
  1. Sangat ringan tanpa overhead memory dan proses dari Xorg/Wayland server compositor (menghemat ~100-200MB RAM).
  2. Boot time jauh lebih cepat langsung dari framebuffer/DRM ke aplikasi.
  3. Mengurangi potensi latency pada rendering jadwal salat berbasis SDL2 + ImGui.
  4. Plymouth melepaskan DRM master (`plymouth quit --retain-splash`) tepat saat SDL2 KMSDRM mengambil alih buffer tampilan sehingga transisi mulus tanpa kedip hitam.

### B. Sistem Splash Screen Plymouth (`jws-animated`)
Splash screen mendukung 3 mode yang diatur lewat `/boot/splash.conf`:
1. `MODE=image`: Gambar statis (PNG/JPG).
2. `MODE=frames`: Urutan file frame PNG (`frame_001.png`, `frame_002.png`, ...).
3. `MODE=gif`: File animasi GIF yang otomatis dikonversi oleh `splash-apply`.

#### Parameter Konfigurasi (`/boot/splash.conf`):
```ini
ENABLED=yes                       # yes/no
MODE=gif                          # image | frames | gif
IMAGE=/boot/splash/logo.png       # dipakai bila MODE=image
FRAMES_DIR=/boot/splash/frames    # dipakai bila MODE=frames
GIF=/boot/splash/boot.gif         # dipakai bila MODE=gif
FPS=15                            # frame per detik
LOOP=yes                          # yes/no
BACKGROUND_COLOR=#000000          # warna latar (hex)
IMAGE_SCALE=fit                   # fit | fill | center | stretch
POSITION=center                   # center | top | bottom
TEXT=Memuat jadwal salat...       # teks tampilan
TEXT_COLOR=#FFFFFF
```

#### Mekanisme Cache & Batas Aman:
- Skrip systemd oneshot `/usr/local/bin/splash-apply` menghitung SHA-256 hash dari file konfigurasi dan media.
- Jika hash tidak berubah, boot berjalan instan (cache hit).
- Jika ada perubahan GIF atau konfigurasi baru:
  - GIF diekstrak ke urutan PNG dengan subsampling otomatis jika frame > **60 frame**.
  - Resolusi dibatasi maksimal 720p (1280x720) dan total ukuran tema dijaga **di bawah 20 MB** agar initramfs tidak membengkak.
  - Jika GIF rusak atau file hilang, otomatis fallback ke logo statis bawaan tanpa menggagalkan boot sistem.
  - Memperbarui initramfs (`update-initramfs -u`) agar animasi tampil sedini mungkin pada boot berikutnya.

#### Opsi Konversi GIF Manual di PC:
Bagi pengguna yang ingin boot pertama sangat cepat tanpa proses konversi di perangkat, tersedia utilitas di host:
```bash
./tools/gif2splash.sh animasi_keren.gif /media/user/BOOT/splash/frames 45 1280x720
```
Lalu atur `MODE=frames` di `/boot/splash.conf`.

---

## 5. Konfigurasi Konsol UART Debug & HDMI

### A. Perilaku Output Konsol
- Urutan kernel cmdline: `console=tty1 console=ttyS0,115200 quiet splash loglevel=3 vt.global_cursor_default=0`.
- Karena `ttyS0` diletakkan terakhir pada argumen console, `/dev/console` diarahkan ke UART, sehingga seluruh log boot, dmesg, dan interaksi terminal serial aktif penuh tanpa mengotori layar HDMI.
- HDMI hanya menampilkan splash screen elegan Plymouth lalu langsung berpindah ke aplikasi JWS.
- Layar login alternatif tersedia di `tty2` (tekan `Ctrl+Alt+F2` jika keyboard HDMI terhubung).

### B. Pinout UART Debug Orange Pi Zero 3
- Header 3-pin serial debug Orange Pi Zero 3 terletak di dekat port USB/Ethernet:
  - **Pin 1 (GND)**: Hubungkan ke GND USB-UART adapter.
  - **Pin 2 (RX)**: Hubungkan ke TX USB-UART adapter.
  - **Pin 3 (TX)**: Hubungkan ke RX USB-UART adapter.
- **Logika Tegangan**: **3.3V TTL** (Dilarang menggunakan 5V langsung!).
- **Perintah Koneksi di PC Host**:
  ```bash
  picocom -b 115200 /dev/ttyUSB0
  # atau
  minicom -D /dev/ttyUSB0 -b 115200
  ```

---

## 6. Akses Remote & Keamanan SSH

### A. Fitur Keamanan Default
- User non-root: `jws` (anggota grup `sudo`, `video`, `audio`, `render`, `input`).
- Password default awal: `jws` (disarankan segera diganti).
- `PermitRootLogin no`: Login root langsung via SSH ditolak.
- **First-Boot Host Keys**: Host key SSH tidak disimpan di image untuk mencegah kerentanan security duplikasi key. Service `ssh-setup.service` membuat host keys unik secara otomatis saat boot pertama.
- **Headless SSH Key Setup**: Pengguna dapat menyalin kunci publik SSH mereka ke `/boot/authorized_keys` di partisi FAT32 lewat komputer Windows/Mac/Linux. Saat boot, file ini otomatis dipindahkan ke `/home/jws/.ssh/authorized_keys` dengan permission `600`.

### B. Konfigurasi Sistem `/boot/system.conf`
```ini
HOSTNAME=jws-pi
SSH_ENABLED=yes
SSH_PORT=22
SSH_PASSWORD_AUTH=no
SERIAL_CONSOLE=yes
SERIAL_BAUD=115200
```

### C. Jaringan WiFi Headless `/boot/wifi.conf`
```ini
WIFI_ENABLED=yes
WIFI_SSID="Nama_WiFi_Masjid"
WIFI_PASSWORD="Password_WiFi_123"
WIFI_COUNTRY="ID"
```

---

## 7. Eksekusi Build Otomatis

Cukup jalankan satu perintah:
```bash
sudo ./scripts/build_all.sh
```
Hasil akhir file image siap burn:
`output/orangepi_zero3_jws.img`

---

## 8. Verifikasi & Simulasi di QEMU

Jalankan pengujian virtual sebelum burn ke SD Card:
```bash
./runQemu output/orangepi_zero3_jws.img
```
- **Login Serial Console**: Langsung muncul prompt di terminal host.
- **Login SSH**: Buka terminal lain di host:
  ```bash
  ssh -p 2222 jws@localhost
  ```

---

## 9. Checklist Pengujian Hardware Fisik (Board Orange Pi Zero 3)

Fitur yang perlu diverifikasi pada board nyata:
- [ ] **UART Debug Fisik**: Verifikasi output serial 115200 baud pada pin header UART0.
- [ ] **HDMI Fisik & EDID**: Verifikasi handshake resolusi monitor TV/HDMI masjid (1080p / 720p).
- [ ] **Kehalusan Animasi GPU**: Performa Plymouth script module dan rendering Dear ImGui pada Mali G31 (Panfrost).
- [ ] **GPIO Infra Red (IR)**: Uji sensor receiver VS1838B menggunakan `ir-keytable -t` atau `evtest /dev/input/eventX`.
- [ ] **Audio ALSA**: Uji output audio analog atau HDMI menggunakan `aplay -l` dan `speaker-test -t sine -f 1000`.
- [ ] **WiFi & Bluetooth Onboard**: Verifikasi modul wireless (CDW-20U5622 / UniSoC / RTL8821CS) dengan `nmcli device wifi list` atau `iwlist wlan0 scan`.
