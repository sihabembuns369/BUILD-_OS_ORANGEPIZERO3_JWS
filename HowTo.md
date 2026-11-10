# ORANGE PI ZERO 3
## Requirement
 > Debian based / ubuntu
    
```
sudo apt update
sudo apt install build-essential qemu-user-static qemu-system-arm \
gcc-aarch64-linux-gnu g++-aarch64-linux-gnu bison flex libssl-dev bc u-boot-tools
```

# VERSI 2
```
sudo apt update
sudo apt install git build-essential gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
bison flex libssl-dev bc u-boot-tools qemu-system-aarch64 meson ninja-build \
pkg-config libdrm-dev
```


# COMPILE Kompilasi ARM Trusted Firmware (ATF)
```
git clone https://github.com/ARM-software/arm-trusted-firmware.git --depth 1
cd arm-trusted-firmware

make CROSS_COMPILE=aarch64-linux-gnu- PLAT=sun50i_h6 DEBUG=1 bl31
```
> Lokasi Hasil:
Setelah selesai, file yang kamu butuhkan ada di:
build/sun50i_h6/debug/bl31.bin

## Copy ATF ke U-Boot
```
cp arm-trusted-firmware/build/sun50i_h6/debug/bl31.bin u-boot/
```

## Kompilasi Bootloader (U-Boot)


```
git clone https://github.com/u-boot/u-boot.git --depth 1
```

## Config
```
cd u-boot && make CROSS_COMPILE=aarch64-linux-gnu- orangepi_zero3_defconfig
```

## Build
```
make CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)
```
> Hasil: File u-boot-sunxi-with-spl.bin.

# Kompilasi Kernel Linux (Mainline)
```
git clone  
cd linux
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- menuconfig
```
> Cari Device Drivers -> Graphics support.

Aktifkan Direct Rendering Manager (DRM) dengan menekan Y.

Setelah itu, masuk ke Display Engine Support (sun4i-drm) (sekarang seharusnya sudah muncul).

Cari dan centang (Y):

Allwinner A10 Display Engine support

Support for Allwinner A10 HDMI Output

Cari Console display driver support -> Aktifkan Framebuffer Console support.
```
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image modules dtbs

make modules_install INSTALL_MOD_PATH=./output_modules

cp -r ./output_modules/lib/modules/* ../my_rootfs/lib/modules/
```


> Hasil: arch/arm64/boot/Image dan arch/arm64/boot/dts/allwinner/sun50i-h618-orangepi-zero3.dtb.

# BUSYBOX

```
git clone https://git.busybox.net/busybox --depth 1
cd busybox && make CROSS_COMPILE=aarch64-linux-gnu- defconfig
```

## COMPILE

```
make CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)
make CROSS_COMPILE=aarch64-linux-gnu- install
```

```
make CROSS_COMPILE=aarch64-linux-gnu- install
```

## DI my_rootfs
```
mkdir -p dev proc sys mnt root tmp etc
touch etc/inittab
 touch fstab
 touch profile
```

for i in ../build/patch/kernel/archive/sunxi-6.6/patches.armbian/arm64-dts-sun50i-h618-orangepi-zero3-Enable-GPU-mali.patch; do patch -p1 < $i; done
patching file arch/arm64/boot/dts/allwinner/sun50i-h618-orangepi-zero3.dts
Hunk #1 succeeded at 22 (offset -6 lines).


cp ../build/config/kernel/linux-sunxi64-current.config .config



<!-- # Jalankan di terminal Orange Pi
depmod -a

# Sekarang coba muat secara berurutan
modprobe unisoc_wcn
modprobe sprdwl_ng -->