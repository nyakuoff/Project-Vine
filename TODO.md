# TODO (priority order)

The goal is the **desktop** client (Windows or macOS). Sober/Android does not count.

1. **Sign in (needs the user).** Run on the real desktop (`VINE_DISPLAY=:0 tests/run-roblox-darling.sh 600`),
   choose Sign In → Quick Login, enter the shown code on a device already signed in. Then record whether the
   home screen loads. Password sign-in needs a captcha web view (MacOBlox opens one via WebKitGTK).
2. **Real GPU display**: same run on Xwayland/radeonsi — confirm DRI3 presentation, frame rate, terrain shaders.
3. **Join an experience** → input (mouse capture/camera lock), audio, UDP game traffic (MacOBlox notes cover
   these: net_trace.c, raw_mouse.c, audio_hal.c; review before implementing).
4. Upstream Vine's Darling fixes (xattr, fork-exit, cookies, NSDisplay, NSURL, IOKit, resolver, CALayerContext).
5. **Regression watch for Route A.** After each Roblox Windows release, run `tests/route-a-wine-startup.sh` and `tests/hard-error-text.sh`. If the "Wine is not supported." string or the `+0x8B885F` site disappears, Roblox has changed its policy, so revisit D1.
3. *(out of Player scope)* Roblox **Studio** via Vinegar 1.9.4 (installed). It is a desktop Windows client that Roblox does not block under Wine.
4. *(low priority)* Fresh observed Sober session for the record (`tests/sober-stages.sh`).

## Done
- [x] Workspace/host inspection, environment matrix
- [x] Ecosystem research (Sober, Vinegar, Grapejuice, Wine/Proton, Darling)
- [x] Route A on all 7 installed Wine/Proton builds, plus umu-run with the EAC runtime
- [x] Route A refusal decoded: "Wine is not supported." (gdb, passive)
- [x] Route B static analysis (dependencies, API surface, renderers, TLS)
- [x] Darling running rootless; Roblox macOS engine reaches OpenGL init and LuaApp stage
- [x] Roblox HTTPS working (resolver fix); sign-in screen rendered (milestone C)
