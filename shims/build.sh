#!/usr/bin/env bash
# Build Vine's Darling shim layer into .work/vine-overlay (mounted above Darling by tests/darling-ns.sh).
#  - libvinestub.dylib: VineStub base class
#  - new frameworks (CoreML): stubs only
#  - wrapped frameworks: Darling's original is kept as <Name>.darling and re-exported by a
#    wrapper at the original install name that adds the missing symbols.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/shims"
D="$ROOT/.work/darling-root/usr/libexec/darling"     # Darling's macOS root (read-only input)
LAYER="$ROOT/.work/vine-overlay"; NEWL="$LAYER.new"      # built in $NEWL, swapped in only on success
O="$NEWL/usr/libexec/darling"                           # our layer
NEW="CoreML"
WRAP="AppKit AudioToolbox CFNetwork IOKit OpenGL Carbon CoreAudio CoreGraphics CoreServices CoreVideo Foundation GameController Metal QuartzCore ServiceManagement SystemConfiguration VideoToolbox"

rm -rf "$NEWL"; mkdir -p "$O/usr/lib/vine"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cc() {  # cc <out> <install-name> [clang args...]
  local out=$1 id=$2; shift 2
  clang -target x86_64-apple-macos10.13 -dynamiclib -nostdlib -fuse-ld=lld -O2 -w \
    -fobjc-runtime=macosx-10.13 -Wl,-syslibroot,"$D" -I"$SRC" -install_name "$id" -o "$out" \
    "$D/usr/lib/libobjc.A.dylib" "$D/usr/lib/libSystem.B.dylib" \
    "$D/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation" "$@"
}
# "-compatibility_version X -current_version Y" taken from a dylib's own id (dyld enforces them)
vers() { llvm-otool -L "$1" | sed -n '2s/.*compatibility version \([0-9.]*\), current version \([0-9.]*\).*/-Wl,-compatibility_version,\1 -Wl,-current_version,\2/p'; }
fwdir() {  # Versions/<letter> of Darling's copy (A for new frameworks)
  local v; v=$(cd "$D/System/Library/Frameworks/$1.framework/Versions" 2>/dev/null && ls -d [A-Z] | head -1) || true
  echo "System/Library/Frameworks/$1.framework/Versions/${v:-A}"; }

# Link-time stand-in for a renamed copy: carries the copy's path (so a wrapper re-exports the
# copy, not itself) and the original's exports (so shims can reference/extend its symbols).
mktbd() {  # mktbd <original> <copy install name> <out.tbd>
  { printf -- "--- !tapi-tbd\ntbd-version: 4\ntargets: [ x86_64-macos ]\ninstall-name: '%s'\n" "$2"
    printf -- "exports:\n  - targets: [ x86_64-macos ]\n    symbols: [ "
    llvm-nm --arch=x86_64 -g --defined-only -j "$1" | sed "s/.*/'&'/" | paste -sd, -
    printf -- " ]\n...\n"; } > "$3"
}

# Plain-C wrappers for libraries loaded during libSystem start-up: they link only the wrapped
# library (re-exported copy with a renamed id), no libSystem, no initializers.
cwrap() {  # cwrap <install name> <source>
  local K=$1; mkdir -p "$(dirname "$O$K")"
  cp "$D$K" "$O$K.darling"; "$SRC/rename-dylib-id.py" "$O$K.darling"
  mktbd "$D$K" "$K.darling" "$TMP/$(basename "$K").tbd"
  clang -target x86_64-apple-macos10.13 -dynamiclib -nostdlib -ffreestanding -fno-builtin -fno-stack-protector -fuse-ld=lld -O2 \
    -install_name "$K" $(vers "$D$K") -Wl,-reexport_library,"$TMP/$(basename "$K").tbd" -o "$O$K" "$2"
}
cwrap /usr/lib/system/libsystem_kernel.dylib "$SRC/kernel.c"   # xattr + fork/exit fixes
cwrap /usr/lib/libresolv.9.dylib "$SRC/resolv.c"                # thread-safe res_query

STUB=/usr/lib/vine/libvinestub.dylib
cc "$O$STUB" "$STUB" "$SRC/VineStub.m"

for fw in $NEW $WRAP; do
  dir=$(fwdir "$fw"); mkdir -p "$O/$dir"
  extra=(-Wl,-compatibility_version,1.0.0 -Wl,-current_version,1.0.0)   # new frameworks: what Roblox requires
  if [[ " $WRAP " == *" $fw "* ]]; then
    cp "$D/$dir/$fw" "$O/$dir/$fw.darling"
    "$SRC/rename-dylib-id.py" "$O/$dir/$fw.darling"   # else dyld de-dups it into the wrapper (self re-export loop)
    mktbd "$D/$dir/$fw" "/$dir/$fw.darling" "$TMP/$fw.tbd"
    extra=($(vers "$D/$dir/$fw") -Wl,-reexport_library,"$TMP/$fw.tbd")
  fi
  # AppKit's shims use Foundation classes (NSThread, NSThreadSharedInstance)
  [ "$fw" = QuartzCore ] && extra+=("$D/System/Library/Frameworks/OpenGL.framework/Versions/A/OpenGL")
  [ "$fw" = CFNetwork ] && extra+=("$D/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation")
  [ "$fw" = AppKit ] && extra+=("$D/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation" "$D/System/Library/Frameworks/OpenGL.framework/Versions/A/OpenGL")
  cc "$O/$dir/$fw" "/$dir/$fw" -DFW_$fw "$SRC/frameworks.m" "$O$STUB" "${extra[@]}"
  # framework layout symlinks (Darling's originals already have them for wrapped ones)
  [ -e "$D/System/Library/Frameworks/$fw.framework/$fw" ] || {
    ln -sfn A "$O/System/Library/Frameworks/$fw.framework/Versions/Current"
    ln -sfn "Versions/Current/$fw" "$O/System/Library/Frameworks/$fw.framework/$fw"; }
done
# Host-side ELF libs Darling expects but CachyOS lacks (shims/build-ffmpeg.sh)
if [ -d "$ROOT/.work/ffmpeg6/lib" ]; then
  mkdir -p "$NEWL/usr/lib"; cp -a "$ROOT/.work/ffmpeg6/lib/"*.so.* "$NEWL/usr/lib/"
else echo "warning: run shims/build-ffmpeg.sh (Darling media frameworks need FFmpeg 6)" >&2; fi
rm -rf "$LAYER"; mv "$NEWL" "$LAYER"
echo "built: $(find "$LAYER" -type f | wc -l) files"
# the container mounted the previous layer directory: restart it so the new layer is used
"$ROOT/tests/darling-ns.sh" --stop
