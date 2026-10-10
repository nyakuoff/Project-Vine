# Decisions

## D1 — Do not work around Hyperion (2026-10-09)
Route A fails inside Roblox's anti-tamper (RESEARCH §2), deterministically, before any graphics/audio/network code runs. Every way past it — patching the DLL, faking syscall results, hiding Wine — means defeating a security mechanism. Out of scope by project rules, and it risks the user's account.
**Rejected**: DXVK/prefix/dependency tuning. They cannot affect a failure that happens before any of those components load.
**Revisit if**: Roblox officially re-allows Wine/Proton. `tests/route-a-wine-startup.sh` will show a different exit path.

**Update (2026-10-09, after the user asked to try anti-cheat-oriented Proton builds)**:
- Tested all 7 installed Wine/Proton builds, plus the full umu-run/Proton path with the EAC runtime. All of them hit the same Hyperion check.
- Decoded the refusal: `"Wine is not supported."` / `"Version Error"`.
- Proton's anti-cheat support only covers EAC and BattlEye, which Roblox does not use.
- **Declined**: Wine forks or settings whose purpose is to hide Wine (e.g. hiding Wine exports, spoofing the environment, emulating Windows syscall numbers so Hyperion's probes pass). Against an explicit "Wine is not supported" policy, these are detection evasion, not compatibility work.

## D2 — Reject Route B for implementation (2026-10-09)
The macOS client is not Hyperion-protected and has an OpenGL backend. But it hard-links ~30 Apple frameworks, and Darling lacks CoreML, has stub WebKit and GameController, and has experimental AppKit. The only recorded Roblox-on-Darling attempt failed during crypto init (#885). The estimated effort is a multi-person-year runtime project, with no upstream to land it in.
**Deferred**: an empirical Darling run. It would only confirm the predicted dyld failure and costs a multi-hour Darling build (TODO #3).

## D3 — Adopt Sober as the playable route (2026-10-09)
Sober runs the official Android Roblox client natively. It is installed on the target host, and it has reached join → connected → sustained play on this hardware. The brief says not to build new things when existing work can be reused. Sober is closed source with an EULA that forbids reverse engineering, so Vine does not modify or inspect it. Vine only reads its logs.

## D4 — No new launcher (2026-10-09)
Sober already provides install, update handling and launch. A Vine launcher would just duplicate it. Vine ships diagnostics instead: `tests/env.sh` and `tests/sober-stages.sh`.

## D5 — Isolated, reversible experiments
Wine prefixes live in `.work/` (gitignored) with one prefix per Wine build, and runs use Xvfb. Client artifacts stay in `artifacts/` (gitignored, Roblox-copyrighted). No host packages were installed or changed.

## D6 — Route B via Darling, fixes as an overlay layer (2026-10-09)
The user prioritised the macOS client. Darling runs rootless from the release debs inside a user
namespace, avoiding a host install. Fixes go in an overlay above Darling (wrappers that re-export
renamed originals, categories, runtime detours) instead of a Darling fork, so they are small, testable
(`tests/darwin/`) and individually upstreamable. Roblox's own binary is never modified.
**Rejected**: macOS VM (Apple EULA on non-Apple hardware, and no GPU for Navi 3x); building Darling from
source (hours, not needed until a fix must go inside Darling).

## D7 — OpenGL backend for Route B
Roblox's Metal pack is precompiled metallibs (Darling's Metal→Vulkan layer is early); the GLSL 3.2 pack
compiles on Mesa natively. Selected through Roblox's own `FFlagDebugGraphicsPreferOpenGL` local setting.

## D8 — Reuse MacOBlox findings selectively (2026-10-09)
The user pointed to MacOBlox, a mature project on the same route. Vine reuses its *findings* where they
cover open problems and keeps its own leaner mechanics (rootless user-namespace overlay instead of an
LD_PRELOAD that fakes root and copies the macOS root; wrapper frameworks instead of one injected dylib).
**Not adopted**: `patch_startup_throttle.py` (edits Roblox's binary; Vine never modifies the client) and
blocking Roblox telemetry hosts (interferes with Roblox's own traffic; not a compatibility fix).
(Superseded: see D9 for the IPC namespace; D10 and D11 for the throttle patch and telemetry, which the
user asked for after this review.)

## D9 — Darling keeps the host SysV IPC namespace (2026-10-09, user-approved)
Mesa's X11 presentation uses MIT-SHM; across Darling's private IPC namespace the X server cannot attach
the segments and frames vanish. `shims/host/keep-ipc.c` (LD_PRELOAD for `darling`/`darlingserver` only)
drops CLONE_NEWIPC; PID/mount/UTS isolation stay. The user judged this isolation trade-off acceptable
(unlike anything touching anti-cheat). Same conclusion MacOBlox reached.

## D10 — Patch Roblox's start-up render throttle (2026-10-09, user-requested)
Finding credited to MacOBlox. Vine's own patcher (`patches/startup_throttle.py`) locates the site
structurally, changes 2 bytes in Vine's prefix copy only, supports --check/--undo, and refuses on any
mismatch. Measured: 240 vs 189 frames in the first 6 s. This supersedes D6's "never modify the client"
for this one, user-chosen, cosmetic patch; no security or anti-cheat code is touched.

## D11 — Block telemetry hosts (2026-10-09, user-requested)
User policy: no data collection. `shims/resolv.c` fails lookups of telemetry/analytics/crash-report hosts
immediately (list built from observed traffic + names in the binary; functional hosts excluded; see the
file). Limit: telemetry sent through `apis.roblox.com` paths can't be blocked by hostname.

## D12 — Join games over RakNet (2026-10-10)
Roblox's newer RbxTransport connection completes its handshake under Darling, then the channel open
fails ~10 s later (error 256). Four rounds of Darling socket fixes (recvfrom flags, connectx,
sendmsg/recvmsg/setsockopt translation; all verified by `tests/darwin/udp_probe.m`) did not change
that. The deciding flags (`UseRbxTransportClient`/`Server`, …) are not locally overridable (runtime
read-back stayed 1). Following MacOBlox's finding (credited), `patches/raknet_transport.py` makes the
client choose RakNet, which Roblox servers still accept. Vine's own patcher locates the four sites
through the flags' registrations and refuses on any mismatch; it independently arrived at MacOBlox's
offsets for 0.742.0.7421053. Compatibility only: no security or anti-cheat code is touched.
`VINE_RBXTRANSPORT=1` restores the original. **Revisit**: root-cause RbxTransport under Darling.
