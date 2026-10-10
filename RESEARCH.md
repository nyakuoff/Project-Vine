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

**The hard error is an explicit refusal** [V]. Wine stubs `NtRaiseHardError`, so the dialog never appears. `tests/hard-error-text.sh` sets a gdb breakpoint on Wine's unix `NtRaiseHardError` and reads the arguments (passive; nothing is modified):

```
status=0x50000018 count=4 mask=0x3
param[0] = 'Wine is not supported.'
param[1] = 'Version Error'
param[2] = 0x10  (MB_ICONERROR)
```
(`logs/route-a-hard-error-text-wine-11.19-20261009.txt`)

**Every installed Wine/Proton build** [V] (`logs/route-a-summary-20261009.txt`):

| Build | Wine base | Hyperion first syscall | Result |
|---|---|---|---|
| system wine | 11.19 | +0x8B885F | "Wine is not supported." → 0xC00000BB |
| GE-Proton11-1 | 11.0 staging | +0x8B885F | same |
| GE-Proton10-34 | 10.0 staging | +0x8B885F | same |
| Proton 11.0 | 11.0 | +0x8B885F | same |
| Proton Experimental | 11.0 | +0x8B885F | same |
| Proton Hotfix | 11.0 | +0x8B885F | same |
| UMU-Proton-10.0-4 | 10.0 | +0x8B885F | crashes *earlier*: the raw syscall is misrouted to `NtQueryObject` with a garbage info class, and the next one faults inside Wine's syscall dispatcher (0xC0000005). Not progress. |
| GE-Proton11-1 via **umu-run** (full Proton script + Steam Linux Runtime container) + `PROTON_EAC_RUNTIME` | 11.0 staging | +0x8B885F | same refusal, exit 187 |

**Anti-cheat Proton runtimes do not apply** [V]:
- Proton's anti-cheat support is per-vendor. Proton's `ntdll.so` redirects `easyanticheat*.dll` or BattlEye DLLs to the Linux-bridged runtime given in `PROTON_EAC_RUNTIME`/`PROTON_BATTLEYE_RUNTIME`.
- Roblox contains **zero** EAC or BattlEye references, and the EAC runtime was loaded 0 times in the umu run.
- No umu/GE protonfixes entry exists for Roblox.
- Hyperion has no Linux/Proton opt-in comparable to the ones EAC and BattlEye offer developers.

**Interpretation**:
- This is a deliberate Wine-detection policy implemented inside Hyperion. It matches Roblox's March 2024 block.
- It is not a missing dependency, prefix configuration, Proton-version or DXVK issue, and no stock Wine/Proton build can avoid it.
- Getting past it requires hiding Wine from Hyperion or patching Hyperion. That is defeating an anti-tamper control, which is out of scope (DECISIONS.md D1).

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

## 5. Route B in practice — macOS client on Darling (2026-10-09)

Setup (no root, no install): official Darling 0.1.20260608 release debs unpacked into `.work/`,
run inside an unprivileged user+mount namespace (`tests/darling-ns.sh`). Vine's shim layer
(`shims/`, built on the host with clang + ld64.lld, no Apple SDK) is overlaid above Darling.

Progress of RobloxPlayer 0.742.0.7421053 (x86_64), each step evidenced in `logs/` / Roblox's own log:

| Stage | Blocker found | Fix (shims/) |
|---|---|---|
| dyld load | CoreML missing; 72 symbols missing from 13 frameworks | stub CoreML + wrapper frameworks re-exporting renamed copies |
| dyld load | wrapper re-exported itself (dyld de-dups by install name) | `rename-dylib-id.py` |
| Darling media frameworks | need FFmpeg 6 sonames, host has FFmpeg 9 | `build-ffmpeg.sh` (6.1.1, no deps) |
| AppKit view setup | HiDPI APIs absent (`convertSizeToBacking:` …) | identity categories (1x) |
| crash reporter init | Darling xattr: unprefixed names, getxattr returns 0 | `kernel.c` xattr wrappers |
| crash reporter launch | forked child's exit ran Mesa atexit → pthread_join hang | single-threaded exit skips host atexit |
| HTTP thread | Darling CFNetwork cookie parser NULL deref | replacement parser + runtime detour |
| render thread | per-thread NSDisplay → "Failed to connect to a window server" | one NSDisplay per process + XInitThreads |
| startup paths | `+[NSURL fileURLWithPath:relativeToURL:]` missing | Foundation category |
| device watch | IOKit matching notification with NULL port | IOKit wrapper returns error |

Reached: `applicationDidFinishLaunching`, local ClientSettings honored (OpenGL backend), reflection
DB validated, **OpenGL 4.6 renderer initialized on Mesa** (llvmpipe under Xvfb), SurfaceController
started, `stage: LuaApp`. Process now stays alive (no crash in 120 s) but nothing is drawn yet.

**2026-10-09 (later): sign-in screen renders.** Further fixes, each found from evidence (traces, gdb
counters, EGL error codes, back-buffer reads):

| Blocker | Evidence | Fix |
|---|---|---|
| `HttpError: DnsResolve` | xtrace: threads write DNS queries to *another thread's* socket (shared `_vcsock`); Darling's resolver calls non-reentrant `res_query` | `shims/resolv.c`: per-call `res_ninit`/`res_nquery` |
| NULL deref at IOKit cleanup | sigframe recovery: `IONotificationPortDestroy(NULL)` | NULL-safe destroy |
| Black window, 60 flushes/s | `eglSwapBuffers` → EGL_BAD_SURFACE; current context ≠ Roblox's: Darling's layer compositor (`-[CALayerContext renderLayer:]`) leaves its own GL context current | save/restore context around `renderLayer:` |
| Still black, swaps succeed | back buffer has content; Mesa log: `Failed to attach to x11 shm` ×2134 (Darling's private SysV IPC namespace vs X server) | test Xvfb runs without MIT-SHM (real GPU displays use DRI3) |

Result: Roblox's own HTTPS (bundled curl/OpenSSL) works (version check returns real data; logged-out
API calls answer 401 as expected), Lua app runs, and the sign-in screen is drawn
(`logs/route-b-first-frame-20261009.png`).

Note: my DNS baseline comparison (`tests/darwin/dns.m` with/without the shim) was invalidated by a
concurrent harness run; the evidence for the fix is the xtrace plus Roblox's errors disappearing.

### MacOBlox (github.com/aubree-lat/MacOBlox, MIT, v0.21patch1) — reviewed 2026-10-09
Same route (Darling 0.1.20260608 + shim, OpenGL by hiding Metal). Their notes report main menu,
Quick Login, avatar and games working. Independent agreement with Vine on: CALayerContext GL-context
restore, xattr, exit, DNS concurrency, IPC namespace vs X11 shared memory. Additional areas they cover
that Vine has not reached: input (mouse capture/camera lock, raw mouse), audio HAL, captcha web view for
password sign-in, UDP/RakNet reliability under Darling, darlingserver lock/ulock fixes, Wayland bridge.
Not adopted (see DECISIONS D8): binary patch of Roblox's startup throttle, blocking Roblox telemetry hosts.

**2026-10-09 (evening): input and quitting.**

| Symptom | Evidence | Fix |
|---|---|---|
| Clicks "freeze everything" (user, KDE) | `CGAssociateMouseAndMouseCursorPosition` ~150/s → `grabMouse:` + 2 `warpMouse:` each: Darling grabs/warps when told *associated* (inverted) | correct sense, act on change only |
| Clicks ignored | event tracer: down/up reach `RobloxOgreView` but no `mouseMoved:`; `buttonNumber`=1 for left; `timestamp` since 2001 vs `systemUptime` since 1970 | windows accept mouse-moved; macOS button numbers (`NSEvent` and `NSEvent_mouse`); both clocks = seconds since boot |
| Close slow (13 s) / never (Xvfb) | `WM_DELETE_WINDOW` received; close scheduled as NSRunLoop perform that Roblox's CFRunLoop doesn't service; Cocotron `_checkForTerminate` unconditional (MacOBlox finding) | close via main dispatch queue; macOS "terminate after last window closed" via delegate; 3 s teardown watchdog |
| Frames lost under Xvfb | MIT-SHM across IPC namespaces | D9 |

Result: Sign In opens the sign-in page (`logs/route-b-signin-page-20261009.png`); close quits in ~3 s.
Still open: Roblox's own teardown blocks ~10 s in `std::thread::join` (not telemetry, not the fd-limit
kqueue scan — both measured); the watchdog hides it. Headless GPU testing: KWin `--virtual` + Xwayland
renders on radeonsi, but XTest input doesn't reach clients there.

**2026-10-09 (night): joining a game.** The user's test: black screen after joining, then a crash.

| Symptom | Evidence | Fix |
|---|---|---|
| Crash ~1 s after the game-server connection | core sigframe: write to a GCD worker's guard page; its 512 KiB stack held ~900 copies of `start_wqthread → … → __workq_kernreturn`. Darling's `workq_kernreturn` re-enters `_start_wqthread` on reuse without resetting the stack pointer (its comment says it does; XNU does) | `kernel.c`: THREAD_RETURN / KEVENT_RETURN run from the worker's stack top (`tests/darwin/workq_reuse.m`: crashed at ~900 jobs, now 2000+ with no drift). MacOBlox found the same bug independently |
| No sound (FMOD error 51 at `getNumDrivers`) | `tests/darwin/coreaudio_props.m`: Darling answers `'who?'` for the device's streams, buffer frame size, latency, transport, clock; no stream objects; listeners refused; `AudioGetCurrentHostTime` stub returns 0 | CoreAudio wrapper answers them from the device's real format (property list credited to MacOBlox) |
| Start-up crash once audio queries succeed | sigframe: `AudioOutputUnitStop` → `dispatchCall` NULL interface: Darling treats a disposed unit as live | instance check also requires the manager to still hold it (`audiounit_misuse.m`) |
| FMOD audio threads overflow in Darling's RPC code (MacOBlox finding) | — | `pthread_attr_setstacksize` floor 8 MiB (`thread_stack.m`) |
| Signed out at every launch (open) | Correction: the Player's only `SecItem*` calls are in `KeychainSecureStorage` (Studio cookie sharing). It asks `NSHTTPCookieStorage` for cookies on every request (`vine-cookie: get …` trace), so cookie persistence is the right layer; Set-Cookie expiry parsing verified (`cookie_header.m`). Why the login was not saved needs a traced sign-in | `vine-cookie:` trace (names/domains only). Earlier guess: Roblox keeps its login in the Keychain (`SecItemAdd`, generic password), not a cookie (`syncCookiesFromNativeToEngine was skipped`); Darling's SecItem calls hang waiting for a security daemon (MacOBlox: not persisted) | Security wrapper keeps generic passwords in `~/Library/Keychains/Vine-GenericPasswords.plist` (0600) (`keychain_persist.m`) |

| Kicked ~10 s after the game connection opens ("Disconnected", error 256; log: "Rejecting send channel open on failed connection") | `tests/darwin/udp_probe.m`: `recv(MSG_DONTWAIT)` on an empty UDP socket blocked until SO_RCVTIMEO: Darling's `sys_recvfrom` computes the Linux flags but passes the Darwin ones (0x80 = Linux MSG_EOR); `connectx` unimplemented (ENOSYS) | `kernel.c`: translate recvfrom flags; `connectx` as bind + connect + optional send (both also MacOBlox findings). kqueue EV_CLEAR read events: no loss seen (500/500) |

| Still kicked after the recvfrom fix (handshake 1.4 s instead of 4.4 s, channel open still fails at 10 s) | `udp_probe.m`: `recvmsg` returns sender `sin_len` 2 (only the family byte converted); `sendmsg` with a control message → EINVAL (only the first cmsg converted, Darwin type numbers kept); received control messages keep Linux types; `setsockopt` IP_RECVPKTINFO / IP_RECVTOS / IP_DONTFRAG (+IPv6 forms) → ENOTSUP. Roblox sets IP_DONTFRAG at two sites | `kernel.c`: sendmsg/recvmsg straight to Linux with full address + control-message conversion; setsockopt maps those options (IP_DONTFRAG → IP_MTU_DISCOVER). If the transport still fails, MacOBlox's route is to select RakNet instead (binary patch of transport selection) |
| Signed out at every launch (found) | trace: `.ROBLOSECURITY` arrives through `-[NSHTTPCookieStorage setCookies:forURL:mainDocumentURL:]`, an empty stub in Darling; the store stayed empty | implemented via `setCookie:` (`cookie_header.m`) |

| In game (RakNet, D12): freezes at any movement | 285k "Warp to" lines in one session (~4000/s): with the mouse locked Roblox warps the cursor every frame, each warp is a real X move that Darling's grab turns into a huge-delta motion event and warps back (MacOBlox notes describe the same fight) | CoreGraphics: `CGWarpMouseCursorPosition` ignored while the mouse is disassociated; X11Display `warpMouse:` without its per-call log line |
| Game list / menus don't scroll | log: `scrollingDeltaY`, `hasPreciseScrollingDeltas`, `phase`, `momentumPhase` unimplemented on Darling's NSEvent | category on NSEvent (wheel: line deltas, not precise, no phases); verified on Xvfb (home page scrolls) |
| No sound: FMOD now lists "PulseAudio 44100/2" but `System::init` fails (51) | — | failing AudioUnit calls logged as `vine-audio:` for the next in-game run |

| ~20-30 fps in game, stalls | Roblox's own counters: averageFPS 29 with only ~4 ms work per frame (GPU 0.3, perform 3.2, present 0.2 ms) — the loop waits; dserver.log: 9217 "PSYNCH: psync_cvwait; invalid sequence numbers" (~90/s in game) | `shims/pthread.c`: condition variables on Linux futexes (MacOBlox finding; `cond_stress.m`: 200k items 4x4 threads, timed wait, broadcast; no psynch errors). Sleeps measured fine (1 ms → 1.07 ms), left alone |
| Freezes while the mouse moves | Darling posts one NSEvent per X motion (1000/s with a gaming mouse; MacOBlox measured the game 180-340 events behind) | moved/dragged events coalesced in Darling's queue (2000 motions → 1 event, final position) |
| No sound | `vine-audio:` trace: `AudioUnitSetProperty(19 AudioChannelLayout, input)` → -10879 | accepted (stereo description) |
| (Vine bug) user's login cookie deleted by a test | Darling's `cookiesForURL:` returns every cookie regardless of URL; the test deleted "its" cookies | cookies filtered by domain/path/Secure/expiry (also stops sending the login cookie to other hosts); Darwin tests run with their own HOME |

| Crash just before the game appears (SIGILL/SIGSEGV in libdispatch `_dispatch_kevent_merge`, once FMOD started) | reproduced: `audiounit_hal.m 30 busy` (1 ms of work per render callback) crashes within seconds; without the work 30 s pass. Darling's AUHAL also passes twice the frame count its buffer holds (1536 frames, 6144 bytes), so a mixer that trusts it overruns the buffer; and Darling's PulseAudio loop closes descriptors before their dispatch sources are unregistered | render callback moved to Vine's thread (buffer-size bounded); PADispatchMainLoop io_* replaced (dup'd descriptors, freed after both cancels); still ~1/3 soak crashes, so by default (as MacOBlox) the output unit never starts Darling's PulseAudio stream: Vine's thread writes to a FIFO played by `pacat` on the host (`tests/host-audio.sh`): 3/3 soaks, real-time pace |

| Camera movement freezes the game (idle 60 fps) | Darling's grab answers every motion event with XWarpPointer + XSync (expensive under Xwayland; ~1000/s with a gaming mouse) and measures deltas from the pin: `tests/darwin/mouse_lock.sh` (300 x 4 px moves while locked): Darling's grab 1240 px total, steps up to 64 px | grab kept, Darling's per-event pinning off; deltas from the previous event; recentre only beyond a quarter window (its own event gets 0): 1200 px exactly, max step 4 px, a few warps instead of one per event |
| FPS drops to ~20 with abilities/particles | Roblox's perf counters show short-lived spikes, not slow average frames | `vine-gl:` log of shader compiles/links over 5 ms, to confirm or rule out first-use compiles |

| Lag in game: Roblox workers 50-82% CPU, darlingserver 33% (user's `tests/profile.sh`) | stack samples: `dserver_rpc_psynch_mutexwait` / `psynch_mutexdrop` — every contended mutex wait/release is a darlingserver request | `pthread.c`: contended `pthread_mutex_lock` spins, then sleeps on a futex picked by address; unlock wakes it (taking/releasing stay Darling's; 10 s fallback to Darling's wait). MacOBlox finding. `mutex_stress.m` 800k exact, darlingserver idle; `cond_stress` 1470 → 183 ms |

Not verified in a game yet (needs the user's account): sound, the black screen (it lasted only the ~4 s
before the crash, so it may just be the loading phase), sustained play.

Open blockers:
- ~~Networking~~ solved for Roblox's own HTTP stack (above). Darling's `NSURLSession` remains a skeleton
  and `NSURLConnection` HTTPS fails (-9836); only two minor Roblox call sites use them.
- ~~Window content~~ solved (above).
- **Sign-in** (needs the user): Quick Login (code entered on a signed-in device) is the route MacOBlox
  reports working; password sign-in needs a captcha web view Darling can't show.
- Some terrain shaders fail to compile on llvmpipe (`GrassVSUnified`, `SmoothClusterVSUnified`).
- iokitd provides no platform-expert/HID services (no device identity, no controllers).
