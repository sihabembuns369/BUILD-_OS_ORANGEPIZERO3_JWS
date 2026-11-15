#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ "$(id -u)" -eq 0 ] && command -v systemctl >/dev/null 2>&1; then
    systemctl stop jws 2>/dev/null || true
    /usr/bin/plymouth quit --wait 2>/dev/null || true
fi

echo "=========================================================="
echo "🕌 Menjalankan Jadwal Sholat Digital di Orange Pi Zero 3"
echo "=========================================================="
exec "$SCRIPT_DIR/jws" "$@"
