# Vine — Roblox on Linux compatibility research

Goal: launch the official Roblox client on Linux, sign in, join experiences, render, play.

## Status (2026-10-09)

| Milestone | Status |
|---|---|
| A. Feasibility established | **Done.** Windows route blocked, macOS route impractical, Android client via Sober works |
| B. Reproducible startup | **Done** for the Windows client. It reaches Hyperion init, which shows "Wine is not supported." and exits. Identical on all 7 Wine/Proton builds, including umu-run with the EAC runtime |
| C. Functional app init | Windows/macOS: not achievable (see below). Sober: yes |
| D. Authenticated session | Sober: evidenced in the user's 2026-10-08 logs |
| E. Playable experience | Sober: join, server connection and a 16-minute session are evidenced in the user's logs. A fresh observed session is TODO #1 |
| F. Usable Linux implementation | Sober is that implementation. Vine adds diagnostics only |

**Bottom line:**
- **Windows Player under Wine/Proton:** Roblox's Hyperion anti-tamper explicitly detects Wine ("Wine is not supported.") and exits, before any graphics code runs. Proton's anti-cheat support (EAC/BattlEye runtimes) doesn't apply because Roblox uses neither. No configuration fixes this, and we do not bypass it.
- **macOS client:** would need a large part of Apple's frameworks reimplemented. There is no runtime close to that today.
- **What works:** the official Android client running natively through [Sober](https://sober.vinegarhq.org/).

Details: [RESEARCH.md](RESEARCH.md) · [COMPATIBILITY.md](COMPATIBILITY.md) · [DECISIONS.md](DECISIONS.md) · [ARCHITECTURE.md](ARCHITECTURE.md) · [TODO.md](TODO.md)

## Play Roblox on Linux

```sh
flatpak install flathub org.vinegarhq.Sober
flatpak run org.vinegarhq.Sober
tests/sober-stages.sh        # after a session: which lifecycle stages were reached
```

Requirements (per Sober docs): kernel ≥ 5.11, x86-64 with SSE4.1, GLES 3.0 (Vulkan 1.1 recommended).

## Reproduce the research

```sh
tests/env.sh                                    # host matrix
# put Roblox packages in artifacts/win and artifacts/mac (not committed)
tests/route-a-wine-startup.sh                   # system Wine
tests/route-a-wine-startup.sh ~/.local/share/Steam/compatibilitytools.d/GE-Proton11-1/files/bin/wine
```

Needs `wine`, `xvfb-run`, and `llvm-objdump`/`objdump` for static inspection. Nothing is installed or changed on the host. Prefixes go in `.work/`.
