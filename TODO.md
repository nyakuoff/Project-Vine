# TODO (priority order)

The goal is the **desktop** client (Windows or macOS). Sober/Android does not count.

1. **Sign in (needs the user)** — clicks now work. Run on the real desktop (`VINE_DISPLAY=:0 tests/run-roblox-darling.sh 600`),
   choose Sign In → Quick Login, enter the shown code on a device already signed in. Then record whether the
   home screen loads. Password sign-in needs a captcha web view (MacOBlox opens one via WebKitGTK).
2. **Real GPU display**: same run on Xwayland/radeonsi — confirm DRI3 presentation, frame rate, terrain shaders.
3. **Join an experience (user test)** — crash after join fixed (workqueue stack), FMOD's HAL queries answered,
   login kept in the Keychain. Verify: picture after join (was black for ~4 s before the crash), sound,
   WASD + mouse look (MacOBlox notes: raw_mouse.c), sustained UDP play, still signed in after a restart.
4. Find the ~10 s thread join in Roblox's teardown (matters for leaving games too).
4b. Closing from in game (user, 2026-10-10): Roblox's own close/leave button needs several clicks; Alt+F4
   sometimes does nothing. Log: after WM_DELETE_WINDOW the window is unmapped and mapped again and the game
   continues. Darling also logs a stream of LeaveNotify during play (pointer leaving the window while locked;
   MacOBlox confines the pointer to the window).
4c. FPS gap (user: ~140 where native is ~240): Roblox's counters show ~5 ms of work per frame; profile in game
   (tests/profile.sh) at high frame rate. MSAA: Roblox still reports "Texture: MSAA 0" on radeonsi even with
   the core profile (llvmpipe: 1).
5. Upstream Vine's Darling fixes (xattr, fork-exit, cookies, NSDisplay, NSURL, IOKit, resolver, CALayerContext).
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
