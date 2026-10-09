#!/usr/bin/env bash
# Build tests/darwin/<name>.m for macOS on the host and run it inside Darling (with Vine shims).
# Usage: tests/darwin/run.sh <name>     exit status = the test's
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
D="$ROOT/.work/darling-root/usr/libexec/darling"
OUTDIR="$ROOT/.work/darwin-tests"; mkdir -p "$OUTDIR"   # host path; Darling sees it via /Volumes/SystemRoot
clang -target x86_64-apple-macos10.13 -nostdlib -fuse-ld=lld -w -fobjc-runtime=macosx-10.13 \
  -Wl,-syslibroot,"$D" -o "$OUTDIR/$1" "$ROOT/tests/darwin/$1.m" \
  "$D/usr/lib/libobjc.A.dylib" "$D/usr/lib/libSystem.B.dylib" \
  "$D/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation" \
  "$D/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit" "$D/usr/lib/libresolv.9.dylib" "$D/System/Library/Frameworks/CFNetwork.framework/Versions/A/CFNetwork"
"$ROOT/tests/darling-ns.sh" shell "/Volumes/SystemRoot$OUTDIR/$1"
