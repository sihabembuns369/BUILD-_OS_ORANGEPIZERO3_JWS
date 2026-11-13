# PERAN
Kamu adalah insinyur senior (software, hardware, dan sistem operasi embedded Linux).

# TUJUAN
Bangun image sistem operasi Linux berbasis **Debian minimalis** untuk **Orange Pi Zero 3 (Allwinner H618)** yang:
1. Menampilkan **splash screen yang bisa dikonfigurasi** saat boot: 🆕 **gambar statis, animasi (urutan frame PNG), atau GIF** secara persisten (konsep Anbernic: animasi/gambar terus berputar di HDMI/LCD sampai aplikasi siap).
2. Menjalankan aplikasi jadwal salat (SDL2 + Dear ImGui) secara fullscreen dan otomatis.
3. Memiliki pemisahan konsol yang tegas: **booting yang ada tulisannya memakai mode UART (serial console)**, sedangkan **HDMI / LCD saat booting murni menampilkan animasi / gambar** tanpa bocoran teks.
4. **Bebas dari bloatware**: OS dipastikan seringan mungkin, minimalis murni, tanpa desktop environment, tanpa cache paket, dan tanpa background service/timer yang tidak dibutuhkan.
5. Bisa diakses dan di-debug lewat **UART (serial console)**, **HDMI**, dan **SSH**.
6. Seluruh kode, script, dan dokumentasi build tersimpan rapi di repository GitHub.

# RUANG LINGKUP
- HANYA membangun OS (bootloader, kernel, rootfs, splash screen, akses jarak jauh, konfigurasi sistem, image akhir).
- JANGAN mengubah kode aplikasi jadwal salat. Aplikasi sudah ada; cukup di-install, dikonfigurasi, dan dijalankan otomatis.

# SPESIFIKASI TEKNIS
| Komponen    | Ketentuan |
|-------------|-----------|
| Base OS     | Debian minimalis (debootstrap / rootfs minimal), arsitektur arm64, **bebas bloatware** (bersih dari cache, man-db, dokumen, dan timer non-esensial) |
| Kernel      | Linux versi stable terbaru yang mendukung H618 / Orange Pi Zero 3 |
| Bootloader  | U-Boot yang mendukung Orange Pi Zero 3 (upstream bila tersedia) |
| UI          | Display stack paling ringan untuk SDL2 (KMS/DRM murni tanpa X11/desktop environment bloat) |
| Splash      | Plymouth dengan tema modul `script` (mendukung animasi frame). Mode persistent ala Anbernic (tidak dimatikan oleh systemd sebelum aplikasi siap) |
| 🆕 Konversi GIF | `ffmpeg` atau `imagemagick` (pilih yang paling kecil dependensinya) untuk mengubah GIF menjadi frame PNG |
| Autostart   | Aplikasi jadwal salat berjalan otomatis saat boot (systemd service), restart otomatis jika crash |
| Konsol      | UART debug (`ttyS0`, 115200 8N1) untuk **seluruh teks booting**, HDMI (`tty1`) **khusus grafis animasi/gambar** |
| Remote      | OpenSSH server aktif saat boot |
| 🆕 RTC Eksternal | Modul I2C DS3231 (`rtc-ds1307` / `rtc-ds3232` di bus I2C, alamat `0x68`). Otomatis sinkronisasi waktu dua arah (`hwclock -s` saat boot, `hwclock -w` saat shutdown/ganti jam) |

# 🆕 SPLASH SCREEN: GAMBAR / ANIMASI / GIF (dinamis via config)
## Perilaku
- Splash tampil sedini mungkin saat boot di HDMI, menutupi log boot di layar (`quiet splash loglevel=3`, cursor console disembunyikan).
- Tiga mode tampilan, dipilih lewat config:
  1. `image`: satu gambar statis (PNG/JPG).
  2. `frames`: folder berisi urutan frame PNG (`frame_001.png`, `frame_002.png`, ...).
  3. `gif`: file GIF animasi. Plymouth tidak memutar GIF langsung, jadi GIF **dikonversi menjadi urutan frame PNG** oleh script `splash-apply`. Gunakan `-coalesce` (atau setara) agar frame GIF yang memakai disposal/transparansi tidak rusak.
- Animasi dimainkan oleh tema Plymouth `script` dengan kecepatan sesuai `FPS`. Dukung `LOOP=yes` (ulang terus sampai aplikasi siap) atau `LOOP=no` (berhenti di frame terakhir).
- Splash tetap tampil sampai aplikasi jadwal salat siap menampilkan UI, lalu hilang mulus (tanpa layar hitam/berkedip dan tanpa konflik DRM master antara Plymouth dan SDL2).
- Animasi harus tetap halus: jangan sampai memperlambat boot atau memakan CPU/RAM berlebihan. Batasi sesuai bagian "Batas aman".

## Konversi dan cache
- `splash-apply` (systemd oneshot) membaca `/boot/splash.conf`, lalu:
  1. Menghitung hash dari config + file media.
  2. Jika hash **sama** dengan boot sebelumnya, tidak melakukan apa pun (boot cepat).
  3. Jika hash **berubah**, ia mengonversi GIF ke frame, mengecilkan ke resolusi layar, membuat ulang tema Plymouth, lalu menjalankan `update-initramfs` agar splash tampil di boot awal. Boot yang mengonversi ini boleh lebih lama dan harus dicatat di log.
- Sediakan juga script `tools/gif2splash.sh` untuk konversi manual di PC (hasilnya folder frame siap salin ke `/boot/splash/frames/`), supaya perangkat tidak perlu memasang tool konversi berat bila pengguna memilih cara itu. Jelaskan opsi yang dipilih dan alasannya di `HowTo.md`.
- Frame hasil konversi disimpan di cache (`/var/cache/splash/`), bukan di partisi FAT.

## Config
- Lokasi: `/boot/splash.conf` (partisi FAT agar bisa diedit dari PC). Sediakan `splash.conf.example`.
- Parameter minimal:

```ini
# /boot/splash.conf
ENABLED=yes                       # yes/no
MODE=gif                          # image | frames | gif
IMAGE=/boot/splash/logo.png       # dipakai bila MODE=image
FRAMES_DIR=/boot/splash/frames    # dipakai bila MODE=frames
GIF=/boot/splash/boot.gif         # dipakai bila MODE=gif
FPS=15                            # kecepatan animasi (frame per detik); 0 = ikuti timing GIF
LOOP=yes                          # yes/no
BACKGROUND_COLOR=#000000          # warna latar (hex), juga mengisi sisi kosong
IMAGE_SCALE=fit                   # fit | fill | center | stretch
POSITION=center                   # center | top | bottom
TEXT=Memuat jadwal salat...       # teks di bawah media (boleh kosong)
TEXT_COLOR=#FFFFFF
PROGRESS_BAR=no                   # yes/no
MIN_DURATION=3                    # detik minimum tampil
ROTATION=0                        # 0 | 90 | 180 | 270
```

## Batas aman (validasi wajib di `splash-apply`)
- Maksimum frame: **60** (kelebihan frame dikurangi merata/di-subsample).
- Resolusi frame otomatis diperkecil agar tidak melebihi resolusi layar; disarankan 720p atau lebih kecil untuk animasi.
- Ukuran total frame/tema dijaga kecil (target **di bawah 20 MB**) agar initramfs dan waktu boot tidak membengkak. Jika terlampaui, kurangi frame/resolusi otomatis dan catat peringatan di log.
- Format tidak didukung, file hilang, GIF rusak, atau nilai tidak valid: **fallback ke logo default statis**, boot tidak boleh gagal, alasan dicatat di `journalctl -u splash-apply`.
- Opsional: splash paling awal di U-Boot (`splash.bmp`) hanya gambar **statis** (U-Boot tidak memutar animasi). Bila dipakai, ambil frame pertama animasi.

## Kriteria khusus splash
- Mengganti gambar, animasi, atau GIF hanya dengan mengedit `/boot/splash.conf` dan menaruh file di `/boot/splash/`, tanpa build ulang image.
- Ganti GIF → reboot → animasi baru tampil. Reboot berikutnya memakai cache (tanpa konversi ulang).
- Ada animasi default kecil (< 2 MB) di repo sebagai contoh.
- `HowTo.md` mendokumentasikan format yang didukung, resolusi/FPS yang disarankan, batas frame, cara memakai `gif2splash.sh`, dan cara memecahkan masalah splash.

# OUTPUT KONSOL: UART + HDMI
## Perilaku
- **UART (Mode Teks)**: Semua booting yang ada tulisannya (log U-Boot, kernel printk, dan systemd `[ OK ]` unit status) **HANYA muncul di UART** (`console=ttyS0,115200` di board / `ttyAMA0` di QEMU). Aktifkan `serial-getty` autologin user `jws`.
- **HDMI / LCD (Mode Grafis)**: Layar HDMI / LCD saat booting **MURNI menampilkan animasi / gambar** splash tanpa ada teks boot log sedikit pun (`quiet splash loglevel=3 plymouth.ignore-serial-consoles vt.global_cursor_default=0`).
- Urutan cmdline: `console=tty1 console=ttyS0,115200`, sehingga `/dev/console` adalah UART dan seluruh log error serta status boot keluar di serial.
- **Splash hanya tampil di HDMI.** Layar HDMI tidak menampilkan log boot dan kursor konsol dimatikan.
- Layanan pemati splash bawaan systemd (`plymouth-quit.service`, `plymouth-quit-wait.service`, dan `getty@tty1.service`) **wajib di-mask** agar animasi di HDMI/LCD tidak tertutup atau beralih ke teks sebelum aplikasi siap (konsep Anbernic).
- Siapkan `getty` di `tty2` untuk login lewat keyboard HDMI tanpa mengganggu aplikasi di `tty1`.
- Dokumentasikan di `HowTo.md`: pin UART debug Orange Pi Zero 3 (TX, RX, GND), level 3.3V, perintah koneksi (contoh: `picocom -b 115200 /dev/ttyUSB0`).

# AKSES SSH
## Perilaku
- `openssh-server` aktif saat boot (`ssh.service` enabled), port default 22 (bisa diubah di config).
- **Host key dibuat saat boot pertama** (bukan di-bake ke image). Pastikan boot pertama tidak gagal jika entropi rendah.
- **Keamanan default**:
  - `PermitRootLogin no`. Buat user non-root (mis. `jws`) dengan `sudo`.
  - Tanpa password default lemah yang tertanam permanen. Pilih: (a) password awal sementara yang wajib diganti saat login pertama, atau (b) hanya kunci publik. Jelaskan pilihan di `HowTo.md`.
  - Kunci publik di `/boot/authorized_keys`; script `ssh-setup` (systemd oneshot) menyalinnya ke `~/.ssh/authorized_keys` dengan permission benar.
  - `PasswordAuthentication yes|no` diatur lewat config.
- **Jaringan**: Ethernet DHCP otomatis; WiFi headless dari `/boot/wifi.conf`; hostname tetap (mis. `jws-pi`) dengan `avahi-daemon` agar bisa `ssh jws@jws-pi.local`.
- SSH tidak boleh memperlambat atau memblokir boot aplikasi jadwal salat.

## Config
- Lokasi: `/boot/system.conf` (partisi FAT). Sediakan `system.conf.example`. Dibaca oleh `system-apply` (systemd oneshot); nilai tidak valid memakai default aman dan dicatat ke `journalctl -u system-apply`.

```ini
# /boot/system.conf
HOSTNAME=jws-pi
SSH_ENABLED=yes              # yes/no
SSH_PORT=22
SSH_PASSWORD_AUTH=no         # yes/no
SERIAL_CONSOLE=yes           # yes/no
SERIAL_BAUD=115200
```

> Jangan menyimpan password asli di repo. Hanya commit file `.example`.

## Kriteria khusus konsol dan SSH
- Log boot lengkap di UART; HDMI hanya menampilkan splash lalu aplikasi.
- Bisa login lewat UART, HDMI/TTY, dan SSH.
- SSH root ditolak dan host key unik per image.

# KEBUTUHAN HARDWARE (wajib berfungsi)
1. **GPIO untuk Infra Red / remote**: aktifkan overlay/driver IR (gpio-ir / lirc / rc-core), sediakan konfigurasi pin dan cara test input remote.
2. **Audio**: driver ALSA aktif, perangkat suara terdeteksi, ada perintah uji (contoh: `aplay`).
3. **WiFi**: driver dan firmware terpasang, bisa konek lewat konfigurasi (wpa_supplicant / NetworkManager / iwd), tersedia template konfigurasi.
4. **Bluetooth**: driver, firmware, dan BlueZ terpasang; layanan aktif saat boot.
5. **Display (HDMI)**: driver DRM/KMS aktif agar splash (termasuk animasi) dan aplikasi tampil.
6. **UART debug**: UART0 aktif sebagai konsol serial (`ttyS0`) di device tree.
7. **Ethernet**: driver aktif untuk akses SSH lewat kabel.
8. 🆕 **RTC Eksternal (DS3231 via I2C)**: Driver kernel `rtc-ds1307` / `rtc-ds3232` aktif, instansiasi modul alamat `0x68` pada bus I2C (header Pin 3 SDA & Pin 5 SCL), sinkronisasi otomatis waktu sistem dari RTC saat boot (`hwclock -s`) dan penyimpanan waktu ke RTC saat shutdown/ubah jam (`hwclock -w`), sehingga jadwal sholat selalu presisi saat offline tanpa internet.
9. 🆕 **Relay Pengendali Amplifier Eksternal**: Kontrol GPIO output (default Pin 12 / PC6) untuk menyalakan saklar daya amplifier masjid sebelum adzan/tarhim diputar dan mematikannya kembali setelah suara selesai agar amplifier tidak mendengung terus-menerus.
10. 🆕 **Kontrol Kipas Pendingin CPU Otomatis**: Layanan pengawas suhu termal SoC Allwinner H618 (`/sys/class/thermal/thermal_zone0/temp`), otomatis menyalakan kipas (default Pin 10 / PC9 via transistor/MOSFET) saat suhu CPU >= 65°C dan mematikan kembali saat suhu dingin <= 50°C.

# 🆕 DOKUMENTASI WIRING HARDWARE LENGKAP (ORANGE PI ZERO 3)

## Diagram Pinout Header 26-Pin Orange Pi Zero 3
```
                  +3.3V Power  ( 1) ( 2)  +5V Power
             I2C3_SDA / PI6    ( 3) ( 4)  +5V Power
             I2C3_SCL / PI5    ( 5) ( 6)  GND
                 PI1 / IR_RX   ( 7) ( 8)  UART1_TX / PH2
                         GND   ( 9) (10)  PC9 / FAN_CONTROL
      PC6 / RELAY_AMPLIFIER    (11) (12)  PC5
                         PC8   (13) (14)  GND
                        PC11   (15) (16)  PC10
                  +3.3V Power  (17) (18)  PC14
              SPI1_MOSI / PH7  (19) (20)  GND
              SPI1_MISO / PH8  (21) (22)  PC15
              SPI1_CLK  / PH6  (23) (24)  SPI1_CS / PH5
                         GND   (25) (26)  PC1 / IR_ALT
```

---

## Tabel Koneksi Pin Per Komponen

### 1. Modul RTC I2C (DS3231)
| Pin Modul DS3231 | Pin Header Orange Pi Zero 3 | Catatan Khusus |
|------------------|-----------------------------|----------------|
| **VCC**          | **Pin 1** (3.3V)            | Gunakan 3.3V (Aman untuk baterai CR2032 standar) |
| **GND**          | **Pin 6** (GND)             | Ground |
| **SDA**          | **Pin 3** (I2C3_SDA / PI6)  | Jalur Data I2C Bus 3 |
| **SCL**          | **Pin 5** (I2C3_SCL / PI5)  | Jalur Clock I2C Bus 3 |

### 2. Sensor Remote Infra Red (IR Receiver VS1838B / TSOP4838)
| Pin Receiver IR  | Pin Header Orange Pi Zero 3 | Catatan Khusus |
|------------------|-----------------------------|----------------|
| **VCC**          | **Pin 1** atau **Pin 17** (3.3V) | Daya receiver 3.3V |
| **GND**          | **Pin 9** atau **Pin 14** (GND) | Ground |
| **OUT / DATA**   | **Pin 7** (PI1 / GPIO 78)   | Input sinyal remote NEC |

### 3. Modul Relay Pengendali Amplifier Eksternal
*Berfungsi menyalakan saklar AC amplifier eksternal saat murottal/adzan berbunyi dan mematikan setelah selesai.*
| Pin Modul Relay  | Pin Header Orange Pi Zero 3 | Catatan Khusus |
|------------------|-----------------------------|----------------|
| **VCC**          | **Pin 2** atau **Pin 4** (5V)   | Daya koil relay 5V |
| **GND**          | **Pin 9** atau **Pin 20** (GND) | Ground bersama |
| **IN / SIGNAL**  | **Pin 11** (PC6 / GPIO 70)  | Kontrol ON/OFF logic 3.3V |
| **NO & COM**     | Saklar Listrik Amplifier    | Memutus/menyambung jalur AC amplifier |

### 4. Kipas Pendingin CPU Otomatis (Fan 5V via Transistor/MOSFET)
*Kipas dikontrol otomatis via transistor 2N2222 / S8050 / N-Channel MOSFET.*
| Terminal Kipas   | Koneksi Rangkaian            | Keterangan |
|------------------|------------------------------|------------|
| **Kipas (+) Merah** | **Pin 2** atau **Pin 4** (5V)| Daya kipas 5V |
| **Kipas (-) Hitam** | Kolektor Transistor / Drain  | Saklar ground oleh transistor |
| **Basis / Gate**    | **Pin 10** (PC9 / GPIO 73)   | Melalui resistor 1k Ohm ke Pin 10 |
| **Emitter / Source**| **Pin 9** atau **Pin 14** (GND) | Ground bersama |

### 5. Audio (Output Suara Masjid)
- **Output Utama**: Audio HDMI (Digital PCM stereo) langsung ke TV / HDMI Audio Splitter.
- **Output Eksternal**: USB DAC / USB Sound Card mini (Plug & Play ALSA) atau HDMI Audio Extractor untuk disambungkan ke Mixer / Amplifier Masjid via jack 3.5mm / RCA.

---

# 🆕 INTEGRASI RTC EKSTERNAL: DS3231 (I2C)
## Tujuan & Perilaku
- Jam jadwal sholat **wajib langsung presisi** sejak detik pertama boot meskipun tanpa koneksi internet (masjid tanpa WiFi/Ethernet atau saat listrik padam lalu hidup kembali).
- Menggunakan modul Real Time Clock presisi tinggi **DS3231** (kompensasi suhu TCXO + baterai backup CR2032/LIR2032).
- Modul terhubung ke bus I2C Orange Pi Zero 3 pada alamat `0x68`.

## Koneksi Pin Fisik (Header GPIO 26-Pin Orange Pi Zero 3)
| Pin Modul DS3231 | Pin Header Orange Pi Zero 3 | Fungsi |
|------------------|-----------------------------|--------|
| **VCC**          | **Pin 1** (3.3V)            | Daya modul (gunakan 3.3V aman untuk baterai CR2032 standar) |
| **GND**          | **Pin 6** (GND)             | Ground (bisa juga Pin 9, 14, 20, 25) |
| **SDA**          | **Pin 3** (I2C3_SDA / PI6)  | Jalur data I2C (I2C bus 3) |
| **SCL**          | **Pin 5** (I2C3_SCL / PI5)  | Jalur clock I2C (I2C bus 3) |

## Arsitektur & Mekanisme di Linux
1. **Modul Kernel**:
   - `i2c-dev`: Antarmuka userspace I2C.
   - `rtc-ds1307` atau `rtc-ds3232`: Driver RTC Dallas/Maxim DS3231.
2. **Instansiasi Otomatis I2C**:
   - Skrip `system-apply` / service systemd memeriksa kehadiran bus `i2c-3`.
   - Menginstansiasi perangkat ke kernel:
     ```bash
     echo ds3231 0x68 > /sys/class/i2c-adapter/i2c-3/new_device 2>/dev/null || true
     ```
   - Kernel otomatis membuat device node `/dev/rtc1`.
3. **Sinkronisasi Dua Arah (Otomatis)**:
   - **Saat Booting (RTC -> Jam Sistem Linux)**:
     - Sistem menjalankan: `hwclock --hctosys -f /dev/rtc1 2>/dev/null || hwclock -s`
     - Jam Linux langsung sinkron dengan waktu akurat dari baterai DS3231 sebelum aplikasi jadwal sholat dimulai.
   - **Saat Shutdown / Reboot (Jam Sistem Linux -> RTC)**:
     - Systemd saat stop service menjalankan: `hwclock --systohc -f /dev/rtc1 2>/dev/null || hwclock -w`
     - Waktu terakhir disimpan ke chip DS3231.
   - **Saat Jam Diatur Manual / Sinkron Internet (NTP)**:
     - Aplikasi memicu `hwclock -w -f /dev/rtc1` sehingga chip RTC selalu menyimpan waktu terbaru yang valid.
4. **Perintah Diagnostik & Pengujian**:
   - Cek deteksi modul di bus I2C: `i2cdetect -y 3` (alamat `0x68` akan muncul `68` atau `UU` jika driver aktif).
   - Baca waktu dari modul RTC: `hwclock -r -f /dev/rtc1`
   - Tulis waktu sistem saat ini ke RTC: `hwclock -w -f /dev/rtc1`

# REFERENSI
- Panduan build: baca `HowTo.md` terlebih dahulu. Jika ada langkah yang kurang atau salah, perbarui `HowTo.md`.
- Script QEMU: `runQemu`.
- Repository GitHub: `https://github.com/sihabembuns369/BUILD-_OS_ORANGEPIZERO3_JWS.git`

# GIT & GITHUB
## Repository
- Remote `origin`: `https://github.com/sihabembuns369/BUILD-_OS_ORANGEPIZERO3_JWS.git`
- Jika folder proyek belum berupa repo Git: `git init`, tambahkan remote `origin`, lalu `git fetch` dan sinkronkan dengan isi remote sebelum menambah commit (jangan menimpa riwayat yang ada).
- Branch utama: `main`. Pekerjaan di branch `dev`; gabungkan ke `main` hanya setelah semua Kriteria Lulus Uji terpenuhi.

## Yang di-commit
- Script build, konfigurasi kernel (`.config` / defconfig), patch kernel dan U-Boot, device tree overlay, konfigurasi rootfs, systemd unit, script `splash-apply`, `system-apply`, `ssh-setup`, 🆕 `tools/gif2splash.sh`, tema Plymouth, `splash.conf.example`, `system.conf.example`, logo dan 🆕 animasi default (kecil), `runQemu`, `HowTo.md`, `CHANGELOG.md`, `README.md`.

## Yang TIDAK boleh di-commit (masukkan ke `.gitignore`)
- File image `*.img`, `*.img.gz`, `*.img.xz`
- Hasil build dan cache: `output/`, `build/`, `rootfs/`, `*.o`, `*.ko`, tarball sumber kernel/U-Boot, 🆕 frame hasil konversi (`cache/`, `frames_out/`)
- File sensitif: password WiFi, token, kunci privat SSH, host key, `authorized_keys` asli, `wifi.conf` dan `system.conf` asli, `.env`
- 🆕 GIF/video buatan pengguna yang besar
- File lebih dari 50 MB. Image dibagikan lewat **GitHub Releases** (atau Git LFS).

## Aturan commit
- Commit kecil dan atomik per perubahan logis.
- Format pesan: `tipe(area): deskripsi singkat`; tipe: `feat`, `fix`, `docs`, `build`, `chore`, `test`.
  - contoh: `feat(splash): dukung mode gif dan frames dengan cache hash`
- Jalankan `git status` dan `git diff --stat` sebelum commit agar tidak ada file terlarang yang ikut.
- Setiap commit yang mengubah sistem ikut memperbarui `CHANGELOG.md`.

## Kapan push
- Push ke `origin dev` setelah tiap milestone: toolchain, U-Boot, kernel, rootfs, konsol/SSH, splash, integrasi aplikasi, lulus uji QEMU.
- Push ke `origin main` (merge dari `dev`) hanya saat semua kriteria lulus, lalu buat tag versi (mis. `v0.1.0`).
- Dilarang `git push --force` ke `main`. Jangan menulis ulang riwayat yang sudah dipush.

## Autentikasi
- Gunakan SSH key, `gh auth login`, atau `GITHUB_TOKEN` yang sudah disediakan di environment.
- JANGAN menulis token/password ke file, script, commit, atau log. JANGAN menanam token di URL remote.
- Jika autentikasi tidak tersedia atau push ditolak, jangan mengakali. Lanjutkan commit lokal, catat kendalanya di `CHANGELOG.md`, dan beri tahu pengguna langkah yang dibutuhkan.

# ALUR KERJA (ikuti berurutan)
1. **Pelajari**: baca `HowTo.md` dan `runQemu`, catat dependensi dan struktur proyek.
2. **Siapkan Git**: cek/inisialisasi repo, atur remote `origin`, buat `.gitignore`, buat branch `dev`, commit awal, push.
3. **Siapkan toolchain**: install cross-compiler dan tool build yang dibutuhkan.
4. **Build bootloader** (U-Boot) untuk Orange Pi Zero 3 dengan output konsol serial aktif. Commit + push.
5. **Build kernel** + device tree + modul; aktifkan IR, audio, WiFi, Bluetooth, DRM/KMS, framebuffer console, UART0, Ethernet. Commit + push.
6. **Buat rootfs Debian minimalis**; install paket: SDL2 runtime, dependensi UI, alsa-utils, bluez, wpa_supplicant/NetworkManager, firmware WiFi/BT, plymouth (+ tema script), 🆕 `ffmpeg` atau `imagemagick` untuk konversi GIF, openssh-server, avahi-daemon, sudo. Commit + push.
7. **Atur konsol dan SSH**: kernel cmdline, `serial-getty@ttyS0`, user non-root, hardening `sshd_config`, `ssh-setup`, `system-apply`, `system.conf.example`. Commit + push.
8. 🆕 **Buat sistem splash (gambar/animasi/GIF)**: tema Plymouth `script` yang memutar frame, `splash-apply` (validasi, konversi GIF, cache hash, `update-initramfs`, fallback), `tools/gif2splash.sh`, `splash.conf` + contoh, logo dan animasi default. Commit + push.
9. **Integrasi aplikasi**: pasang aplikasi jadwal salat dan buat systemd service autostart yang berurutan dengan splash (splash ditutup setelah aplikasi siap). Commit + push.
10. **Rakit image** (`.img`) siap burn.
11. **Uji di QEMU** menggunakan `runQemu`: boot, konsol serial (`-serial stdio` / `-nographic`), SSH via port forwarding (`hostfwd=tcp::2222-:22`), HDMI virtual (virtio-gpu), 🆕 dan variasi splash (lihat kriteria).
12. **Perbaiki** jika ada kegagalan, ulangi langkah 11 sampai lulus.
13. **Dokumentasi** hasil akhir.
14. **Rilis**: merge `dev` ke `main`, buat tag versi, push `main` dan tag, unggah image ke GitHub Releases bila diminta pengguna.

# KRITERIA LULUS UJI (wajib terpenuhi sebelum image dinyatakan siap burn)
- [ ] Image boot sampai login/desktop di QEMU tanpa kernel panic
- [ ] Service aplikasi jadwal salat aktif otomatis (`systemctl status` = active)
- [ ] Layanan audio, WiFi, Bluetooth, dan IR terdaftar dan terkonfigurasi
- [ ] 🆕 Modul RTC I2C DS3231 terkonfigurasi untuk sinkronisasi dua arah (`hwclock -s` saat boot, `hwclock -w` saat shutdown)
- [ ] 🆕 Splash teruji minimal 5 variasi: (1) `MODE=image`, (2) `MODE=frames`, (3) `MODE=gif`, (4) `ENABLED=no`, (5) warna/skala/posisi berbeda
- [ ] 🆕 Ganti GIF di `/boot/splash/` lalu reboot: animasi baru tampil; reboot berikutnya memakai cache tanpa konversi ulang
- [ ] 🆕 `LOOP=yes` dan `LOOP=no` berperilaku benar; `FPS` mengubah kecepatan
- [ ] 🆕 GIF rusak, file hilang, frame berlebihan, atau ukuran terlalu besar: fallback ke logo default tanpa boot gagal, tercatat di log
- [ ] 🆕 Animasi tidak membuat boot gagal atau memperlambat signifikan; selisih waktu boot dengan/tanpa animasi tercatat
- [ ] Transisi splash ke aplikasi berjalan tanpa error DRM dan tanpa layar hitam/berkedip
- [ ] Log boot muncul lengkap di konsol serial dan bisa login lewat serial
- [ ] Output HDMI (virtual di QEMU) menampilkan splash lalu aplikasi
- [ ] `ssh.service` aktif otomatis, login SSH berhasil dengan user non-root, login root ditolak
- [ ] Host key dibuat saat boot pertama dan unik per image
- [ ] `/boot/authorized_keys` dan `/boot/system.conf` terbaca benar, nilai tidak valid tidak menggagalkan boot
- [ ] Ukuran image dan waktu boot tercatat
- [ ] Semua hasil uji terdokumentasi
- [ ] Semua perubahan sudah di-commit dan dipush ke GitHub, tanpa file image atau rahasia di repo

> **Catatan**: QEMU tidak dapat meniru hardware H618 secara penuh (GPIO, IR, WiFi, Bluetooth fisik, UART0 fisik, sebagian output display). Kehalusan animasi dan performa di GPU/display Orange Pi yang sebenarnya tidak bisa dinilai di QEMU. Fitur yang tidak bisa diuji di QEMU (UART fisik, HDMI fisik, 🆕 kehalusan animasi di board, splash awal U-Boot, rotasi layar, WiFi/Ethernet nyata) ditandai **"perlu uji di board fisik"** beserta checklist ujinya.

# ATURAN
- **Dilarang burn ke SD card** sebelum semua kriteria lulus uji terpenuhi.
- **Anti-Bloatware Wajib**: OS harus seringan mungkin. Dilarang menyertakan desktop environment, browser, package cache APT, man-db/doc cache, atau kernel duplikat. Timer background yang tidak perlu (`apt-daily`, `man-db`, dll) wajib dinonaktifkan.
- **Pemisahan Tampilan**: Booting yang ada tulisannya wajib memakai mode UART; HDMI/LCD bootingnya murni memakai animasi/gambar tanpa teks.
- **Splash Persistent (Ala Anbernic)**: Splash di HDMI/LCD tidak boleh mati di tengah boot. Hanya aplikasi utama yang berhak mematikan splash saat UI siap.
- Jika ada keputusan teknis yang ambigu, pilih opsi paling sederhana dan stabil, lalu catat alasannya di dokumentasi.
- Jika terblokir, jangan menebak: catat masalah, penyebab dugaan, dan solusi alternatif.
- Jangan pernah mempublikasikan rahasia (token, password WiFi, kunci) ke GitHub.
- Jangan menanam password default yang lemah atau kunci privat ke dalam image.
- 🆕 Splash apa pun tidak boleh menggagalkan atau menunda boot aplikasi jadwal salat; kegagalan splash selalu berujung fallback.

# DOKUMENTASI (wajib setiap ada perubahan)
Setiap perubahan dicatat di `CHANGELOG.md` dengan format:

## [YYYY-MM-DD] Judul perubahan
- Apa yang diubah:
- Alasan:
- File/komponen terdampak:
- Hasil uji (QEMU / board fisik):
- Commit / tag:

Buat juga `README.md` singkat di root repo: deskripsi proyek, cara build (rujuk `HowTo.md`), cara menjalankan QEMU, 🆕 cara mengganti splash (gambar/animasi/GIF), cara terhubung lewat UART dan SSH.

# OUTPUT AKHIR
1. File image siap burn (`.img`), tidak di-commit, dibagikan lewat Releases bila diminta
2. `HowTo.md` yang sudah diperbarui (termasuk panduan splash 🆕 animasi/GIF, UART, dan SSH)
3. `CHANGELOG.md` dan `README.md`
4. `splash.conf.example`, `system.conf.example`, logo dan 🆕 animasi default, 🆕 `tools/gif2splash.sh`
5. Laporan hasil uji (checklist kriteria lulus di atas)
6. Daftar item yang masih perlu diuji di board fisik
7. Repo GitHub yang sudah terupdate (branch `main` + tag versi) dan ringkasan commit yang dipush