#!/usr/bin/env bash
# tools/gif2splash.sh
# Skrip konversi GIF animasi menjadi sequence PNG frames yang siap dipakai Plymouth
# Sesuai spesifikasi AGENTS.md (Max frame: 60, resolusi aman 720p, frame_xxx.png)

set -e

GIF_INPUT="$1"
OUTPUT_DIR="${2:-./frames_out}"
MAX_FRAMES="${3:-60}"
TARGET_RES="${4:-1280x720}"

usage() {
    echo "Penggunaan: $0 <input.gif> [output_dir] [max_frames] [target_res]"
    echo "Contoh    : $0 animation.gif ./frames 45 1280x720"
    exit 1
}

if [ -z "$GIF_INPUT" ] || [ ! -f "$GIF_INPUT" ]; then
    echo "Error: File input GIF '$GIF_INPUT' tidak ditemukan!"
    usage
fi

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/frame_*.png

echo "==> Memproses: $GIF_INPUT"
echo "==> Direktori output: $OUTPUT_DIR"
echo "==> Batas frame: $MAX_FRAMES | Target resolusi: $TARGET_RES"

# Periksa ketersediaan tool (prioritas: ffmpeg, fallback: imagemagick convert)
if command -v ffmpeg >/dev/null 2>&1; then
    echo "==> Menggunakan ffmpeg untuk konversi..."
    TEMP_DIR=$(mktemp -d)
    
    # Ekstraksi seluruh frame sementara ke PNG
    ffmpeg -loglevel error -y -i "$GIF_INPUT" "$TEMP_DIR/raw_%04d.png"
    TOTAL_FRAMES=$(find "$TEMP_DIR" -name "raw_*.png" | wc -l)
    echo "==> Total frame asli: $TOTAL_FRAMES"
    
    if [ "$TOTAL_FRAMES" -eq 0 ]; then
        echo "Error: Gagal mengekstrak frame dari GIF!"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Hitung step jika frame melebihi batas maksimum
    if [ "$TOTAL_FRAMES" -gt "$MAX_FRAMES" ]; then
        STEP=$(awk "BEGIN {print $TOTAL_FRAMES / $MAX_FRAMES}")
        echo "==> Frame melebihi $MAX_FRAMES. Melakukan subsampling merata (step ~$STEP)..."
    else
        STEP=1
    fi
    
    IDX=1
    CURR=1
    while [ "$CURR" -le "$TOTAL_FRAMES" ] && [ "$IDX" -le "$MAX_FRAMES" ]; do
        INT_CURR=$(printf "%.0f" "$CURR")
        [ "$INT_CURR" -lt 1 ] && INT_CURR=1
        [ "$INT_CURR" -gt "$TOTAL_FRAMES" ] && INT_CURR=$TOTAL_FRAMES
        
        SRC_FILE=$(printf "$TEMP_DIR/raw_%04d.png" "$INT_CURR")
        DEST_FILE=$(printf "$OUTPUT_DIR/frame_%03d.png" "$IDX")
        
        # Resize dengan mempertahankan aspect ratio dan fit dalam target resolution
        ffmpeg -loglevel error -y -i "$SRC_FILE" -vf "scale='min(${TARGET_RES%x*},iw*min(${TARGET_RES%x*}/iw\,${TARGET_RES#*x}/ih))':'min(${TARGET_RES#*x},ih*min(${TARGET_RES%x*}/iw\,${TARGET_RES#*x}/ih))'" "$DEST_FILE"
        
        IDX=$((IDX + 1))
        CURR=$(awk "BEGIN {print $CURR + $STEP}")
    done
    rm -rf "$TEMP_DIR"

elif command -v convert >/dev/null 2>&1; then
    echo "==> Menggunakan ImageMagick (convert)..."
    TEMP_DIR=$(mktemp -d)
    convert "$GIF_INPUT" -coalesce "$TEMP_DIR/raw_%04d.png"
    TOTAL_FRAMES=$(find "$TEMP_DIR" -name "raw_*.png" | wc -l)
    echo "==> Total frame asli: $TOTAL_FRAMES"
    
    if [ "$TOTAL_FRAMES" -gt "$MAX_FRAMES" ]; then
        STEP=$(awk "BEGIN {print $TOTAL_FRAMES / $MAX_FRAMES}")
    else
        STEP=1
    fi
    
    IDX=1
    CURR=1
    while [ "$CURR" -le "$TOTAL_FRAMES" ] && [ "$IDX" -le "$MAX_FRAMES" ]; do
        INT_CURR=$(printf "%.0f" "$CURR")
        [ "$INT_CURR" -lt 1 ] && INT_CURR=1
        [ "$INT_CURR" -gt "$TOTAL_FRAMES" ] && INT_CURR=$TOTAL_FRAMES
        
        SRC_FILE=$(printf "$TEMP_DIR/raw_%04d.png" "$INT_CURR")
        DEST_FILE=$(printf "$OUTPUT_DIR/frame_%03d.png" "$IDX")
        
        convert "$SRC_FILE" -resize "${TARGET_RES}>" "$DEST_FILE"
        
        IDX=$((IDX + 1))
        CURR=$(awk "BEGIN {print $CURR + $STEP}")
    done
    rm -rf "$TEMP_DIR"
else
    echo "Error: ffmpeg atau imagemagick tidak terpasang!"
    exit 1
fi

COUNT=$(find "$OUTPUT_DIR" -name "frame_*.png" | wc -l)
TOTAL_SIZE=$(du -sh "$OUTPUT_DIR" | cut -f1)
echo "==> Berhasil! $COUNT frame diekstrak ke: $OUTPUT_DIR (Ukuran total: $TOTAL_SIZE)"
