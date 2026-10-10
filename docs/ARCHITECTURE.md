# Architecture

## Route B: macOS client on Darling

```
RobloxPlayer (macOS x86_64, unmodified*)
        │  dyld
        ▼
 Vine overlay (.work/vine-overlay, built by shims/build.sh)      * optional patches/ modify Vine's copy only
   ├─ wrapper frameworks: AppKit, CoreAudio, AudioToolbox, CFNetwork, Foundation, IOKit, OpenGL,
   │   CoreGraphics, QuartzCore, Security, ...      shims/frameworks.m (one build per framework)
   │     each re-exports Darling's original (renamed *.darling) and adds fixes / missing symbols
   ├─ libsystem_kernel   shims/kernel.c     syscalls: sockets, workqueue, cancellation, memory stats, xattr
   ├─ libsystem_pthread  shims/pthread.c    condition variables and contended mutex waits on futexes
   ├─ libsystem_platform shims/platform.c   fast memmove / memset / strlen
   ├─ libsystem_trace    shims/trace.c      os_log off
   └─ libresolv          shims/resolv.c     thread-safe DNS + telemetry host blocking
        ▼
 Darling (rootless: user + mount namespace, tests/darling-ns.sh)  →  Linux, Mesa, PulseAudio/PipeWire
```

Wrappers rather than a Darling fork keeps each fix small, testable (`tests/darwin/`) and individually upstreamable. Linker-level details: `shims/build.sh`; runtime detours and symbol lookup: `shims/VineStub.m`.

Host side: `shims/host/keep-ipc.c` (keeps the host IPC namespace so X11 shared memory works), `tests/host-audio.sh` (plays game audio with `pacat`), `tests/run-roblox-darling.sh` (launcher; reads `~/.config/vine/vine.conf`), `vine-launcher.py` (settings window).

## Route A: Windows client (research only)

`tests/env.sh` (host matrix) and `tests/route-a-wine-startup.sh` (Windows player in an isolated Wine prefix under Xvfb, `WINEDEBUG=+seh,+loaddll,+process`) document why this route is blocked; archived output is in `docs/evidence/`. `tests/hard-error-text.sh` reads the refusal text passively with gdb.

## Conventions

- Every fix has a regression test in `tests/darwin/` (runs inside Darling via `tests/darwin/run.sh <name>`).
- Findings from other projects are credited where used (MacOBlox); their code is not copied.
- Not committed: `artifacts/` (Roblox's client), `.work/` (Darling, prefixes, build output), `logs/`.
