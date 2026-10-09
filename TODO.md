# TODO (priority order)

The goal is the **desktop** client (Windows or macOS). Sober/Android does not count.

1. **Route B empirical baseline on Darling.** The macOS client is the only desktop client that is not anti-tamper protected.
   - Needs the user's OK: installing Darling is a host change (AUR `darling`, root, multi-hour build).
   - Then: run `RobloxPlayer.app` → record the earliest failure. The prediction is a dyld failure on hard-linked CoreML; otherwise the failure is in corecrypto (Darling #885).
   - If CoreML is the first wall, the next experiment is a minimal CoreML stub framework, then AppKit/`NSOpenGLContext` with the `DebugGraphicsPreferOpenGL` path.
2. **Regression watch for Route A.** After each Roblox Windows release, run `tests/route-a-wine-startup.sh` and `tests/hard-error-text.sh`. If the "Wine is not supported." string or the `+0x8B885F` site disappears, Roblox has changed its policy, so revisit D1.
3. *(out of Player scope)* Roblox **Studio** via Vinegar 1.9.4 (installed). It is a desktop Windows client that Roblox does not block under Wine.
4. *(low priority)* Fresh observed Sober session for the record (`tests/sober-stages.sh`).

## Done
- [x] Workspace/host inspection, environment matrix
- [x] Ecosystem research (Sober, Vinegar, Grapejuice, Wine/Proton, Darling)
- [x] Route A on all 7 installed Wine/Proton builds, plus umu-run with the EAC runtime
- [x] Route A refusal decoded: "Wine is not supported." (gdb, passive)
- [x] Route B static analysis (dependencies, API surface, renderers, TLS)
