#!/usr/bin/env bash
# Darling's release is built on Ubuntu 24.04 and dlopen()s FFmpeg 6 sonames (libavformat.so.60 ...).
# CachyOS ships FFmpeg 9, so build a minimal, dependency-free FFmpeg 6.1.1 into .work/ffmpeg6.
# shims/build.sh copies its libraries into the overlay's /usr/lib.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
V=6.1.1
W="$ROOT/.work/ffmpeg-build"; OUT="$ROOT/.work/ffmpeg6"
mkdir -p "$W"; cd "$W"
[ -f ffmpeg-$V.tar.xz ] || curl -fsSLO "https://ffmpeg.org/releases/ffmpeg-$V.tar.xz"
rm -rf ffmpeg-$V; tar xf ffmpeg-$V.tar.xz; cd ffmpeg-$V
./configure --prefix="$OUT" --enable-shared --disable-static --disable-programs --disable-doc \
  --disable-avdevice --disable-avfilter --disable-postproc --disable-swscale \
  --disable-autodetect $(command -v nasm >/dev/null || echo --disable-x86asm) >/dev/null
make -j"$(nproc)" >/dev/null
rm -rf "$OUT"; make install >/dev/null
ls "$OUT/lib"/*.so.*
