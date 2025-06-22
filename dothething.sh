#!/usr/bin/env bash
set -euo pipefail

#─── Check dependencies ────────────────────────────────────────────────────────
for cmd in ffmpeg jp2a tput; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo >&2 "Error: '$cmd' is not installed. Please install it."; exit 1;
  }
done

#─── Prompt user for input ─────────────────────────────────────────────────────
read -rp "Enter path to video file: " VIDEO
[[ -f "$VIDEO" ]] || { echo >&2 "Error: '$VIDEO' not found."; exit 1; }

read -rp "Enter FPS (default 10): " FPS
FPS=${FPS:-10}

read -rp "Enter output directory (default ascii_output): " OUTDIR
OUTDIR=${OUTDIR:-ascii_output}

#─── Terminal size detection ───────────────────────────────────────────────────
TERM_WIDTH=$(tput cols)
TERM_HEIGHT=$(tput lines)

# Because terminal characters are tall, scale the video accordingly
# Aspect fix: reduce height by a factor (~2) for better fit
CHAR_ASPECT=2
SCALE_WIDTH=$TERM_WIDTH
SCALE_HEIGHT=$(( TERM_HEIGHT * CHAR_ASPECT ))

echo "Detected terminal size: $TERM_WIDTH x $TERM_HEIGHT"
echo "Scaling video to: $SCALE_WIDTH x $SCALE_HEIGHT (pixel dimensions)"

#─── Temp dirs setup ───────────────────────────────────────────────────────────
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
FRAME_DIR="$TMPDIR/frames"
mkdir -p "$FRAME_DIR" "$OUTDIR"

#─── Extract frames using FFmpeg ───────────────────────────────────────────────
echo "Extracting frames from '$VIDEO' at ${FPS} FPS..."
ffmpeg -v error -i "$VIDEO" -vf "fps=$FPS,scale=${SCALE_WIDTH}:${SCALE_HEIGHT}:flags=lanczos" \
  "$FRAME_DIR/frame_%04d.jpg"

#─── Convert frames to color ASCII ─────────────────────────────────────────────
echo "Converting frames to colored ASCII..."
for IMG in "$FRAME_DIR"/frame_*.jpg; do
  FRAME_NAME=$(basename "$IMG" .jpg)
  jp2a --colors --width=$TERM_WIDTH --height=$TERM_HEIGHT "$IMG" > "$OUTDIR/$FRAME_NAME.txt"
done

#─── Playback ──────────────────────────────────────────────────────────────────
echo "Playing ASCII video... (Ctrl+C to exit)"
SLEEP_DELAY=$(awk "BEGIN { printf \"%.3f\", 1/$FPS }")
for FRAME in "$OUTDIR"/frame_*.txt; do
  clear
  cat "$FRAME"
  sleep "$SLEEP_DELAY"
done
