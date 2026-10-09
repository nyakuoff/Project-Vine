# TODO (priority order)

The goal is the **desktop** client (Windows or macOS). Sober/Android does not count.

1. **Route B networking** (current blocker): Darling's `NSURLSession` has no task implementation
   and `NSURLConnection` HTTPS fails with SSL -9836. Next: find whether Roblox's settings/auth requests
   go through NSURLSession, NSURLConnection or its bundled libcurl, then implement the missing layer
   in Darling (upstreamable) — `tests/darwin/urlsession.m` and `urlconnection.m` are the acceptance tests.
   Constraint: normal TLS verification and normal sign-in only.
1b. **Route B rendering**: confirm a window is mapped (Xvfb screenshots are blank); try `VINE_DISPLAY=:0`
   for radeonsi instead of llvmpipe; look at the failing terrain shaders.
1c. Upstream Vine's Darling fixes (xattr, fork exit, cookies, NSDisplay, NSURL, IOKit) to darlinghq.
2. **Regression watch for Route A.** After each Roblox Windows release, run `tests/route-a-wine-startup.sh` and `tests/hard-error-text.sh`. If the "Wine is not supported." string or the `+0x8B885F` site disappears, Roblox has changed its policy, so revisit D1.
3. *(out of Player scope)* Roblox **Studio** via Vinegar 1.9.4 (installed). It is a desktop Windows client that Roblox does not block under Wine.
4. *(low priority)* Fresh observed Sober session for the record (`tests/sober-stages.sh`).

## Done
- [x] Workspace/host inspection, environment matrix
- [x] Ecosystem research (Sober, Vinegar, Grapejuice, Wine/Proton, Darling)
- [x] Route A on all 7 installed Wine/Proton builds, plus umu-run with the EAC runtime
- [x] Route A refusal decoded: "Wine is not supported." (gdb, passive)
- [x] Route B static analysis (dependencies, API surface, renderers, TLS)
- [x] Darling running rootless; Roblox macOS engine reaches OpenGL init and LuaApp stage
