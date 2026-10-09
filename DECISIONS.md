# Decisions

## D1 — Do not work around Hyperion (2026-10-09)
Route A fails inside Roblox's anti-tamper (RESEARCH §2), deterministically, before any graphics/audio/network code runs. Every way past it — patching the DLL, faking syscall results, hiding Wine — means defeating a security mechanism. Out of scope by project rules, and it risks the user's account.
**Rejected**: DXVK/prefix/dependency tuning. They cannot affect a failure that happens before any of those components load.
**Revisit if**: Roblox officially re-allows Wine/Proton. `tests/route-a-wine-startup.sh` will show a different exit path.

## D2 — Reject Route B for implementation (2026-10-09)
The macOS client is not Hyperion-protected and has an OpenGL backend. But it hard-links ~30 Apple frameworks, and Darling lacks CoreML, has stub WebKit and GameController, and has experimental AppKit. The only recorded Roblox-on-Darling attempt failed during crypto init (#885). The estimated effort is a multi-person-year runtime project, with no upstream to land it in.
**Deferred**: an empirical Darling run. It would only confirm the predicted dyld failure and costs a multi-hour Darling build (TODO #3).

## D3 — Adopt Sober as the playable route (2026-10-09)
Sober runs the official Android Roblox client natively. It is installed on the target host, and it has reached join → connected → sustained play on this hardware. The brief says not to build new things when existing work can be reused. Sober is closed source with an EULA that forbids reverse engineering, so Vine does not modify or inspect it. Vine only reads its logs.

## D4 — No new launcher (2026-10-09)
Sober already provides install, update handling and launch. A Vine launcher would just duplicate it. Vine ships diagnostics instead: `tests/env.sh` and `tests/sober-stages.sh`.

## D5 — Isolated, reversible experiments
Wine prefixes live in `.work/` (gitignored) with one prefix per Wine build, and runs use Xvfb. Client artifacts stay in `artifacts/` (gitignored, Roblox-copyrighted). No host packages were installed or changed.
