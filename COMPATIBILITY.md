# Compatibility matrix

## Tested environment (2026-10-09, `tests/env.sh` → `logs/env-20261009.txt`)

| | |
|---|---|
| Distro / kernel | CachyOS rolling, 7.2.9-1-cachyos, x86_64 |
| CPU | Intel Core i7-12700K |
| GPU | AMD RX 7800 XT (RADV NAVI32), Intel UHD 770 |
| Driver | Mesa 26.2.4, Vulkan 1.4.354, OpenGL 4.6 core |
| Session | Wayland / KDE Plasma (Xvfb used for Route A tests) |
| Wine | wine 11.19 (Arch); GE-Proton11-1 (staging 11.0); Proton Experimental (11.0) |
| Sober / Vinegar | 1.8.0 / 1.9.4 (Flatpak) |

## Client artifacts

| Client | Version | Source |
|---|---|---|
| Windows `RobloxPlayerBeta.exe` | 0.742.0.7421053 | `artifacts/win` (Roblox CDN package `RobloxApp.zip`, see `win-manifest.txt`) |
| macOS `RobloxPlayer.app` (x86_64) | 0.742.0.7421053 | `artifacts/mac` |
| Android (via Sober) | AppVersion 741 | fetched by Sober |

## Route comparison

| | A: Windows + Wine/Proton | B: macOS + Darling-class runtime | C: Android + Sober |
|---|---|---|---|
| Feasibility | **Blocked** by design | Theoretically possible, impractical | **Works** |
| Blocker | Hyperion terminates the process under Wine (0xC00000BB) | ~1.6k symbols / 165 classes / 1.3k selectors of Apple API; CoreML/WebKit missing in Darling | Remote-attestation games (Error 318) |
| Complexity to progress | Requires defeating anti-tamper — out of scope | Multi-person-year runtime work | None (install) |
| Tooling | Wine, Proton, DXVK — all mature | Darling (experimental GUI), darling-metal (early) | Sober 1.8.0 |
| Evidence | `logs/route-a-*.log` (3 Wine builds) | Static analysis (RESEARCH §3), Darling #885 | `logs/sober-stages-*.txt`, Sober docs |

## Lifecycle stage results

| # | Stage | Route A (Wine 11.19 / Proton) | Route B | Route C (Sober) |
|---|---|---|---|---|
| 1 | Install / version validation | PASS (manual package extract) | PASS (bundle intact, Info.plist valid) | PASS (AppVersion 741) |
| 2 | Launcher / args | n/a — player started directly | not run | PASS |
| 3 | Runtime init | PASS (prefix, wineserver) | not run (no runtime installed) | PASS |
| 4 | Executable load / process creation | PASS (exe + Hyperion DLL mapped) | predicted FAIL at dyld (CoreML) | PASS |
| 5 | OS services | **FAIL** — Hyperion direct syscalls → `NtRaiseHardError 0x50000018` → exit 0xC00000BB, <5 s | — | PASS |
| 6 | Graphics / audio | not reached | — | PASS (Vulkan, RADV) |
| 7 | Authentication | not reached | — | PASS* |
| 8 | App init | not reached | — | PASS* |
| 9 | Join experience | not reached | — | PASS* (`Joining game`, `Connection accepted`) |
| 10 | Sustained play | not reached | — | PASS* (994 s session, clean exit) |

\* From the user's own 2026-10-08 Sober logs, not a session executed by Vine. Input handling is implied by a 16-minute session but not independently logged.
