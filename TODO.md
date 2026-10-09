# TODO (priority order)

1. **Verify milestone E with a fresh, observed Sober session** (needs the user, because it uses their account): launch Sober, join any experience, move and jump, then run `tests/sober-stages.sh` and save the output to `logs/`. Also record whether keyboard, mouse and gamepad work, since input is the one item not covered by the existing logs.
2. **Regression watch for Route A**: after each Roblox Windows release, rerun `tests/route-a-wine-startup.sh` with system Wine and one Proton build. A different exit code or fault site means Roblox has changed its policy, so revisit D1.
3. *(optional, low value)* **Empirical Darling run**: build Darling (AUR `darling`, multi-hour) and run `RobloxPlayer.app`. The predicted result is a dyld failure because CoreML is hard-linked. Only worth doing if Darling gains CoreML/WebKit.
4. *(out of Player scope)* Roblox **Studio** via Vinegar 1.9.4 (already installed). Confirm login and playtest work on this host if Studio matters to you.
5. Track Sober known issues that affect this host, such as Error 318 attestation titles.

## Done
- [x] Workspace and host inspection, environment matrix
- [x] Ecosystem research (Sober, Vinegar, Grapejuice, Wine/Proton, Darling)
- [x] Route A static and dynamic analysis on 3 Wine builds; earliest failure isolated
- [x] Route B static analysis (dependencies, API surface, renderers, TLS)
- [x] Route selection: Sober (D3)
