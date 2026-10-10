# Vine — Roblox on Linux compatibility research

Goal: launch the official Roblox client on Linux, sign in, join experiences, render, play.

## Status (2026-10-09)

| Milestone | Status |
|---|---|
| A. Feasibility established | **Done.** Windows route blocked, macOS route impractical, Android client via Sober works |
| B. Reproducible startup | **Done** for the Windows client. It reaches Hyperion init, which shows "Wine is not supported." and exits. Identical on all 7 Wine/Proton builds, including umu-run with the EAC runtime |
| C. Functional app init | **macOS client: done** — Roblox's sign-in screen renders on Linux via Darling + Vine shims ([screenshot](logs/route-b-first-frame-20261009.png)). Windows: blocked |
| D. Authenticated session | Sober: evidenced in the user's 2026-10-08 logs |
| E. Playable experience | Sober: join, server connection and a 16-minute session are evidenced in the user's logs. A fresh observed session is TODO #1 |
| F. Usable Linux implementation | Sober is that implementation. Vine adds diagnostics only |

**Bottom line:**
- **Windows Player under Wine/Proton:** Roblox's Hyperion anti-tamper explicitly detects Wine ("Wine is not supported.") and exits, before any graphics code runs. Proton's anti-cheat support (EAC/BattlEye runtimes) doesn't apply because Roblox uses neither. No configuration fixes this, and we do not bypass it.
- **macOS client (active route):** runs on Darling (no root, no install) with Vine's shim layer. It starts, reaches Roblox's servers over HTTPS, and **renders the sign-in screen**. Next: sign in (Quick Login), then join a game. See RESEARCH §5.
- **What works:** the official Android client running natively through [Sober](https://sober.vinegarhq.org/).

Details: [RESEARCH.md](RESEARCH.md) · [COMPATIBILITY.md](COMPATIBILITY.md) · [DECISIONS.md](DECISIONS.md) · [ARCHITECTURE.md](ARCHITECTURE.md) · [TODO.md](TODO.md)

## Play Roblox on Linux

```sh
flatpak install flathub org.vinegarhq.Sober
flatpak run org.vinegarhq.Sober
tests/sober-stages.sh        # after a session: which lifecycle stages were reached
```

Requirements (per Sober docs): kernel ≥ 5.11, x86-64 with SSE4.1, GLES 3.0 (Vulkan 1.1 recommended).

## Route B (macOS client on Darling)

```sh
# once: unpack Darling release debs into .work/darling-root (see RESEARCH §5), then
shims/build-ffmpeg.sh && shims/build.sh       # Vine's shim layer
tests/run-roblox-darling.sh 120               # headless run → logs/darling-roblox-*.log, logs/screens/
VINE_DISPLAY=:0 tests/run-roblox-darling.sh   # on your desktop
tests/darwin/run.sh <test>                    # Darwin regression tests (url_relative, dns, iokit_notify, urlsession, urlconnection)
tests/darling-lastcrash.sh                    # explain the latest crash from its core dump
```

## Reproduce the research

```sh
tests/env.sh                                    # host matrix
# put Roblox packages in artifacts/win and artifacts/mac (not committed)
tests/route-a-wine-startup.sh                   # system Wine
tests/route-a-wine-startup.sh ~/.local/share/Steam/compatibilitytools.d/GE-Proton11-1/files/bin/wine
```

Needs `wine`, `xvfb-run`, and `llvm-objdump`/`objdump` for static inspection. Nothing is installed or changed on the host. Prefixes go in `.work/`.

## Launcher (settings GUI)

`./vine-launcher.py` (Qt 6 / PySide6) sets Vine's options and launches or stops Roblox:
window (desktop or hidden test display), renderer (OpenGL, or Vulkan through Mesa Zink),
camera sensitivity, Mesa frame-rate overlay, time limit, the AMD antialiasing workaround, audio
path, game network protocol (RakNet), the start-up throttle patch and a network trace. It also runs
the profiler (`tests/profile.sh`) and opens `logs/`. Settings are stored in
`~/.config/vine/vine.conf` and read by `tests/run-roblox-darling.sh`, so the command line uses
them too (environment variables of the same names override them).
