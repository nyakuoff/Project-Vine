#!/usr/bin/env bash
# Print the host compatibility matrix (Phase 3). Read-only.
v() { "$@" 2>/dev/null | head -1; }
echo "date:      $(date -Is)"
echo "distro:    $(. /etc/os-release; echo "$PRETTY_NAME $BUILD_ID")"
echo "kernel:    $(uname -r)  arch: $(uname -m)"
echo "cpu:       $(lscpu | sed -n 's/^Model name: *//p')"
lspci | sed -n 's/.*VGA compatible controller: /gpu:       /p'
vulkaninfo --summary 2>/dev/null | awk -F'= ' '/deviceName/{n=$2} /driverInfo/{print "vulkan:    " n " / " $2} /apiVersion/&&!a{a=$2}'
echo "opengl:    $(glxinfo -B 2>/dev/null | sed -n 's/OpenGL core profile version string: //p')"
echo "session:   $XDG_SESSION_TYPE / $XDG_CURRENT_DESKTOP"
echo "wine:      $(v wine --version)"
for p in ~/.local/share/Steam/compatibilitytools.d/*/files/bin/wine ~/.local/share/Steam/steamapps/common/Proton*/files/bin/wine; do
  [ -x "$p" ] && echo "proton:    $(echo "$p" | sed -E 's:.*/(compatibilitytools.d|common)/::;s:/files.*::') ($(v "$p" --version))"
done
flatpak info org.vinegarhq.Sober 2>/dev/null | sed -n 's/^ *Version: /sober:     /p'
flatpak info org.vinegarhq.Vinegar 2>/dev/null | sed -n 's/^ *Version: /vinegar:   /p'
