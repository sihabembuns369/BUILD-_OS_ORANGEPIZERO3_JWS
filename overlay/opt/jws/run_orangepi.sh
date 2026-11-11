#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

export LD_LIBRARY_PATH="$SCRIPT_DIR/lib:$LD_LIBRARY_PATH"

# Mode framebuffer DRM/KMS jika berjalan tanpa server display X11/Wayland
if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    export SDL_VIDEODRIVER=KMSDRM
fi

echo "=========================================================="
echo "🕌 Menjalankan Jadwal Sholat Digital di Orange Pi Zero 3"
echo "=========================================================="
./jadwalsholat_imgui "$@"
