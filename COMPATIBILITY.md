# Compatibility matrix

## Tested environment (2026-10-09, `tests/env.sh` → `logs/env-20261009.txt`)

| | |
|---|---|
| Distro / kernel | CachyOS rolling, 7.2.9-1-cachyos, x86_64 |
| CPU | Intel Core i7-12700K |
| GPU | AMD RX 7800 XT (RADV NAVI32), Intel UHD 770 |
| Driver | Mesa 26.2.4, Vulkan 1.4.354, OpenGL 4.6 core |
| Session | Wayland / KDE Plasma (Xvfb used for Route A tests) |
| Wine | system wine 11.19; GE-Proton11-1, GE-Proton10-34, UMU-Proton-10.0-4, Proton 11.0, Proton Experimental, Proton Hotfix; umu-launcher 1.4.3; Proton EasyAntiCheat Runtime v2 |
| Sober / Vinegar | 1.8.0 / 1.9.4 (Flatpak) |

## Client artifacts

| Client | Version | Source |
|---|---|---|
| Windows `RobloxPlayerBeta.exe` | 0.742.0.7421053 | `artifacts/win` (Roblox CDN package `RobloxApp.zip`, see `win-manifest.txt`) |
| macOS `RobloxPlayer.app` (x86_64) | 0.742.0.7421053 | `artifacts/mac` |
| Android (via Sober) | AppVersion 741 | fetched by Sober |

## Route comparison

| | A: Windows + Wine/Proton | B: macOS + Darling + Vine shims | C: Android + Sober |
|---|---|---|---|
| Feasibility | **Blocked** by design | **In progress**: engine + OpenGL init reached | **Works** |
| Blocker | Hyperion detects Wine and exits: "Wine is not supported." | Darling networking (NSURLSession skeleton, TLS -9836); no visible frame yet | Remote-attestation games (Error 318) |
| Complexity to progress | Requires defeating anti-tamper — out of scope | Incremental Darling fixes (10 landed so far as shims) | None (install) |
| Tooling | Wine, Proton, DXVK — all mature | Darling 0.1.20260608 rootless + `shims/` + crash/exception/coverage tools | Sober 1.8.0 |
| Evidence | `logs/route-a-*.log` (3 Wine builds) | RESEARCH §5, `logs/darling-roblox-*.log`, `tests/darwin/` | `logs/sober-stages-*.txt`, Sober docs |

## Lifecycle stage results

| # | Stage | Route A (Wine 11.19 / Proton) | Route B | Route C (Sober) |
|---|---|---|---|---|
| 1 | Install / version validation | PASS (manual package extract) | PASS (bundle intact, Info.plist valid) | PASS (AppVersion 741) |
| 2 | Launcher / args | n/a — player started directly | not run | PASS |
| 3 | Runtime init | PASS (prefix, wineserver) | not run (no runtime installed) | PASS |
| 4 | Executable load / process creation | PASS (exe + Hyperion DLL mapped) | predicted FAIL at dyld (CoreML) | PASS |
| 5 | OS services | **FAIL** — Hyperion raises `"Wine is not supported."` (`NtRaiseHardError 0x50000018`) → exit 0xC00000BB, <5 s. Same on all 7 Wine/Proton builds and on umu-run with the EAC runtime | — | PASS |
| 6 | Graphics / audio | not reached | — | PASS (Vulkan, RADV) |
| 7 | Authentication | not reached | — | PASS* |
| 8 | App init | not reached | — | PASS* |
| 9 | Join experience | not reached | — | PASS* (`Joining game`, `Connection accepted`) |
| 10 | Sustained play | not reached | — | PASS* (994 s session, clean exit) |

\* From the user's own 2026-10-08 Sober logs, not a session executed by Vine. Input handling is implied by a 16-minute session but not independently logged.

## Route B stage results (Darling 0.1.20260608 + Vine shims, 2026-10-09)

| # | Stage | Result |
|---|---|---|
| 1–4 | bundle, launch, runtime, dyld load | PASS (with shims) |
| 5 | OS services (xattr, fork/exit, IOKit, AppKit display) | PASS (with shims) |
| 6 | Graphics | PASS-partial: OpenGL 4.6 via Mesa initialized; no visible frame yet |
| 6 | Audio | not yet examined |
| 7 | Networking / auth | **FAIL**: Darling NSURLSession is a skeleton; NSURLConnection TLS error -9836 |
| 8 | App init | PASS-partial: `stage: LuaApp` reached |
| 9–10 | Join / play | not reached |
