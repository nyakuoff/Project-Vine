# Research findings

Labels: **[V]** verified (primary source or reproduced locally), **[C]** community claim / inference.
Local evidence lives in `logs/`; scripts in `tests/`.

## 1. Existing ecosystem

| Project | What it is | Player? | Status | Reuse for Vine |
|---|---|---|---|---|
| **Sober** (`org.vinegarhq.Sober`) | Native Linux runtime for the official **Android** Roblox client (x86_64 APK). Not Wine, not an emulator. [V] [FAQ](https://vinegarhq.org/Sober/FAQ/index.html) | **Yes** | Active, 1.8.0 on Flathub, ~190k downloads/mo [V] [Flathub](https://flathub.org/apps/org.vinegarhq.Sober) | Use as-is. Closed source, proprietary EULA forbids RE [V] — Vine only wraps diagnostics around it. |
| **Vinegar** (`vinegarhq/vinegar`) | Wine manager for Roblox **Studio** (Kombucha Wine builds, WineD3D/DXVK, WebView2) [V] [releases](https://github.com/vinegarhq/vinegar/releases) | No — removed in v1.8.0 (2025-02-08) after the March 2024 Wine block [V] | Active, v1.9.4 | Reference for Studio only. |
| **Grapejuice** | Older Wine manager for Player + Studio | No | Abandoned 2024-07: "Roblox is actively hostile towards its Linux userbase" [V] [GitLab](https://gitlab.com/brinkervii/grapejuice) | None. |
| **Wine / Proton** | Win32 compatibility layer | Blocked by Hyperion (see §2) | — | Reproduction harness only. |
| **Darling** | macOS compatibility layer | No record of Roblox working; [issue #885](https://github.com/darlinghq/darling/issues/885) "Roblox Does Not Startup" open since 2020 [V] | Active, GUI "experimental" [V] [README](https://github.com/darlinghq/darling) | None today (see §3). |
| **"REA"** | No Roblox-on-Linux project by that name found [V-absence]. Locally, REA is the `rea` reverse-engineering MCP toolkit used for binary inspection. | — | — | Tooling only. |

**Roblox's stance on Wine (timeline)** [V, staff posts via press]:
- 2023-05: Hyperion ships, Wine breaks; staff: "no plans to release a Linux client, we are aiming to support Wine again" ([GamingOnLinux](https://www.gamingonlinux.com/2023/05/roblox-still-plan-to-make-it-work-with-wine-on-linux/)).
- 2023-08: Wine unofficially restored ([It's FOSS](https://itsfoss.com/news/roblox-wine-support-linux/)).
- 2024-02: staff: Wine used for cheating, "we have exhausted our options" ([GamingOnLinux](https://www.gamingonlinux.com/2024/02/we-can-probably-say-a-final-goodbye-to-roblox-on-linux-with-wine-soon/)).
- 2024-03: Player blocked under Wine/Proton/Steam Deck ([GamingOnLinux](https://www.gamingonlinux.com/2024/03/game-over-for-roblox-on-linux-steam-deck-as-its-now-blocked/)).
- 2024–2026-10: no reversal or Linux announcement found.

## 2. Route A — Windows client under Wine/Proton

Artifact: `RobloxPlayerBeta.exe` FileVersion `0, 742, 0, 7421053`, PE32+ x86-64 GUI.

**Static** [V]:
- The exe's import table contains **only `RobloxPlayerBeta.dll`** — no kernel32/user32/d3d11. All OS API resolution is done at runtime by that DLL.
- Both files carry a `.byfron` section (DLL: 20 MB of it); exe also has `tempest`. This is Hyperion (Byfron) anti-tamper.
- Renderer strings: D3D11 (`ID3D11Device`, `ID3D11VideoDevice`), Vulkan, OpenGL backends exist.

**Dynamic** [V] — `tests/route-a-wine-startup.sh`, isolated prefix, Xvfb, no login:
1. Wine maps the exe and `RobloxPlayerBeta.dll` (native) and ~30 builtin DLLs (crypt32, bcrypt, ole32, shell32, dbghelp, wtsapi32…).
2. Code inside the Hyperion DLL executes **raw `syscall` instructions** with non-Linux, non-ntdll numbers (e.g. `rax 0x769c8036`), trapped by Wine's SIGSYS handler.
3. `NtRaiseHardError 0x50000018` → process terminates with `0xC00000BB` (STATUS_NOT_SUPPORTED; Wine 11.19 shows exit 187 = low byte).

Identical across Wine 11.19, GE-Proton11-1 (wine-staging 11.0) and Proton Experimental (wine 11.0); fault site is the same DLL offset `+0x8B885F` every run. Failure is deterministic and precedes graphics, audio, network and auth.

**Interpretation**: this is Hyperion's environment check rejecting Wine, consistent with Roblox's documented March 2024 block [C: we did not decode the hard-error text]. It is not a missing dependency, prefix configuration, or DXVK issue. The only route past it is defeating anti-tamper, which is out of scope (see DECISIONS.md D1).

## 3. Route B — macOS client

Artifact: `RobloxPlayer.app` 0.742.0.7421053, `LSMinimumSystemVersion 10.13`, SDK 26.2. Main binary is **thin x86_64** Mach-O (Roblox also publishes arm64 on a separate CDN channel [V] [DeployHistory](https://setup.rbxcdn.com/mac/DeployHistory.txt)).

**Static** [V]:
- No `.byfron`/Hyperion markers; ordinary dyld binding.
- Hard-linked: AppKit, Foundation, CoreFoundation, libobjc, Metal, QuartzCore, OpenGL, WebKit, CoreML, AVFoundation, VideoToolbox, CoreMedia, CoreVideo, GameController, ForceFeedback, IOKit, AudioToolbox, AudioUnit, CoreAudio, Carbon, Security, SystemConfiguration, Contacts, CoreServices, CoreGraphics, CoreText, libSystem, libc++, libresolv, libbsm. Weak-linked: CoreHaptics, DeviceCheck, ServiceManagement, UniformTypeIdentifiers, UserNotifications.
- API surface: **1,606** imported symbols across 35 libraries (libSystem 546, libc++ 379, CoreFoundation 121, IOKit 63, AppKit 53, Foundation 49, GameController 38, OpenGL 36, …), **165** Objective-C classes referenced, **~1,348** selector refs (`__objc_selrefs` 0x2a20 / 8).
- Renderers: Metal (`shaders_metal_osx.pack`, `CAMetalLayer`) **and** an OpenGL/GLSL3 backend (`shaders_glsl3.pack`, `NSOpenGLContext`, GL entry points looked up by name, `DebugGraphicsPreferOpenGL` flag). So Metal is not strictly required.
- Networking/TLS is bundled: libcurl 8.19.0-DEV + OpenSSL 3.5.0 + `ssl/cacert.pem`.

**Runtime landscape** [V unless marked]:
- Darling is the only Mach-O-on-Linux runtime with framework coverage. GUI support "experimental", AppKit via Cocotron.
- Darling's Metal (`darling-metal` on `indium`, Metal→Vulkan) is an early separate project; no game reported rendering through it.
- Darling's OpenGL is a thin CGL→EGL layer (Mesa) — the most plausible render path for Roblox's GL backend [C].
- **WebKit and GameController are no-op stubs; no CoreML framework found.** CoreML and WebKit are hard-linked here, so dyld would fail to load the binary without at least stubs [C: predicted, not run].
- Roblox on Darling (issue #885) stalled during crypto/network init (`ccDRBGGetRngState` unimplemented); maintainers: "not a minimal GUI app".

**Estimate**: reaching a rendered frame needs, at minimum, a CoreML stub, real AppKit windowing with `NSOpenGLContext`, corecrypto RNG, IOKit HID/input, plus whatever the 1,348 selectors hit at runtime; login/web views need WebKit. Multi-person-year scale with no upstream path [C]. The macOS client also is not Hyperion-protected today, but there is no guarantee Roblox would tolerate it running outside macOS.

## 4. Route C — official Android client via Sober (existing)

Not in the original brief, but it is the official Roblox client and the only one evidenced to work on Linux.
- Locally installed: Sober 1.8.0, Android client AppVersion 741, Vulkan on RADV (RX 7800 XT).
- The user's own sessions on 2026-10-08 (not run by Vine) show: Vulkan device → window → `Joining game` → `Connection accepted` → 994 s session → disconnect reason 285 → clean exit (`logs/sober-stages-20261008-user-sessions.txt`).
- Known limits [V] ([Troubleshooting](https://vinegarhq.org/Sober/Troubleshooting.html)): experiences with Android Remote Attestation fail with Error 318; only allowlisted FFlags; no multi-instance; Flatpak-only.
