# Architecture

Vine is a research and diagnostics harness, not a runtime (see DECISIONS D3/D4).

```
artifacts/            official client packages (gitignored, not redistributable)
.work/                throwaway Wine prefixes, one per Wine build (gitignored)
tests/env.sh          host matrix → logs/env-*.txt
tests/route-a-wine-startup.sh [wine] [args]
                      Windows player in isolated prefix under Xvfb, 90 s cap,
                      WINEDEBUG=+seh,+loaddll,+process → logs/route-a-<wine>-<ts>.log
tests/route-a-summary.sh [logs]
                      one line per run: build, Hyperion fault offset, hard error, exit code
tests/hard-error-text.sh (+ .gdb)
                      gdb breakpoint on Wine's NtRaiseHardError; prints the message text
tests/sober-stages.sh [log]
                      maps a Sober log onto lifecycle stages 1–10 (read-only, no secrets)
logs/                 redacted evidence ($HOME → ~)
```

## Startup lifecycle as observed

**Route A (Windows/Wine)**
`wine` → ntdll/kernel32 builtins → exe mapped (imports only the Hyperion DLL) → `RobloxPlayerBeta.dll` mapped native → Hyperion loads crypto/COM/shell DLLs → direct `syscall` probes (SIGSYS in Wine) → `NtRaiseHardError` → terminate `0xC00000BB`. Earliest failure: stage 5. Nothing after it is reachable without defeating Hyperion.

**Route C (Sober)**
Sober runtime → Android client libs → Vulkan loader → window (Wayland, hidpi) → device selection (RADV) → DataModel/patch config → `NetworkClient:Create` → `Joining game` → `Connection accepted` → play → `Sending disconnect` → `clean_exit_success`. These are the markers `sober-stages.sh` checks.

## Adding a test
Each test is one shell script in `tests/` that writes evidence to `logs/` and changes nothing outside `.work/`. Its log name records the component version.
