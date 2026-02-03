# Hylab

Hylab is a deterministic, artifact-first testing harness for Hytale server mods. It scans mod inventories, plans coverage, boots isolated server runs, and produces evidence-rich reports so compatibility can be measured, reproduced, and improved with confidence across platforms.

## Goals
- Fast boot tests (offline auth)
- Pairwise coverage arrays with targeted isolation
- Minimal repro bundles
- Optional authenticated join tests
- CSV + summary reports

## Layout
```text
modlab/
  bin/
  config/
  runs/
  repros/
  reports/
  logs/
```

## Requirements
- Java 25 (recommended: Adoptium). `java -version` should report 25.x.
- UDP port 5520 open for server binds (QUIC over UDP).
- Hytale server files and Assets.zip available. See `references/hytale-server-manual.md`.
- First-time server auth uses device flow: `/auth login device`.
  
## AOT Cache
If the bundled `HytaleServer.aot` does not match your Java build, disable AOT:
- Set `UseAOTCache` to `false` in `config/hylab.json`, or
- Set env var `HYLAB_USE_AOT=false`.

## Quick start
1. Copy `config\hylab.example.json` to `config\hylab.json` and edit paths
2. `./modlab.ps1 scan`
3. `./modlab.ps1 plan`
4. `./modlab.ps1 boot`
5. `./modlab.ps1 join` (optional authenticated join)
6. `./modlab.ps1 report`
7. `./modlab.ps1 proofcheck`
8. `./modlab.ps1 bisect`
9. `./modlab.ps1 repro`
10. `./modlab.ps1 scenario -ScenarioPath .\scenario.json`
11. `./modlab.ps1 deps`

## Quick commands (cheat sheet)
| Task | Command |
| --- | --- |
| Scan mods | `./modlab.ps1 scan` |
| Plan coverage | `./modlab.ps1 plan` |
| Boot tests | `./modlab.ps1 boot` |
| Join tests | `./modlab.ps1 join` |
| Report | `./modlab.ps1 report -Json -Csv -Junit` |
| Proofcheck | `./modlab.ps1 proofcheck` |
| Bisect | `./modlab.ps1 bisect -BisectStatus fail,timeout` |
| Repro | `./modlab.ps1 repro` |
| Scenario | `./modlab.ps1 scenario -ScenarioPath .\scenario.json` |
| Deps preflight | `./modlab.ps1 deps` |

## Output selection (report)
- `./modlab.ps1 report -Json -Csv -Junit`
- `./modlab.ps1 report -Out .\reports\custom`
- `./modlab.ps1 report -Lane join -RunId <runId>`

## Dependency preflight
- `./modlab.ps1 deps`
- Outputs: `reports/deps.json` and `reports/deps.md`

## Dependency overrides
Some mods don't declare hard dependencies. You can define them in
`config/dep-overrides.json` (see `config/dep-overrides.example.json`):
```json
{
  "Example:ModA": ["Example:CoreLib"]
}
```
Overrides are merged into dependency expansion for boot/scenario.

## Exclude list
Use `config/excludes.txt` to skip known-bad mods without deleting them (see `config/excludes.example.txt`).
Entries can be filenames or mod IDs (`Group:Name`).

## Chunked boot runs (resume)
Use a fixed `RunId` and slice the plan with `-StartIndex` and `-Count`.
Example:
- `./modlab.ps1 boot -RunId 20260202-full -StartIndex 0 -Count 200`
- `./modlab.ps1 boot -RunId 20260202-full -StartIndex 200 -Count 200`

## Outputs (core artifacts)
- `mods.json`, `mods.csv`: mod inventory and hashes (from `scan`)
- `plan.json`: coverage plan and metadata (from `plan`)
- `results.json`: per-test outcomes (from `report`)
- `proof.json`: proofcheck ledger (from `proofcheck`)
- `repros/manifest.json`: repro bundle manifest (from `repro`)
- `reports/boot-<RunId>.csv`: boot results (from `boot`)
- `reports/join-<RunId>.csv`: join results (from `join`)
- `reports/summary-<RunId>.md`: human summary (from `report`)
- `reports/<RunId>.junit.xml`: CI-friendly results (from `report`)
- `reports/trace-<RunId>.jsonl`: structured trace events
- `reports/resource-<RunId>.csv`: CPU/RAM samples
- `runs/<runId>/test-XXXX/mods.txt`: mod list for each test (small, AI-friendly)
- `runs/<runId>/test-XXXX/mods.json`: mod list + hashes for each test
- `runs/<runId>/index.json`: tiny per-run index (testId -> status + mod list paths)

## Config and overrides
- Copy `config/hylab.example.json` to `config/hylab.json` and edit paths.
- Most settings can be overridden with `HYLAB_*` env vars.
- Keep `config/hylab.json` local; do not commit it.
- Contract details and schema notes live in `paper.md`.

## Join tests (optional)
Join tests start the server with authenticated mode and run a user-supplied
command to attempt a client connection. Configure:
- `JoinCommand` (string, optional) or `HYLAB_JOIN_COMMAND`
- `JoinAuthMode` (`authenticated` or `offline`, default `authenticated`)
- `JoinTimeoutSeconds` or `HYLAB_JOIN_TIMEOUT_SECONDS`

JoinCommand supports placeholders:
- `{host}` `127.0.0.1`
- `{port}` server port
- `{runId}` `{testId}`
- `{testDir}` `{logDir}`

## Definitions
- RunId: unique run identifier used to group results and artifacts.
- TestId: index of a test entry within a run.
- Lane: a test category with explicit entry/success criteria (boot, scenario, proofcheck).

## Safety throttling (recommended for desktops)
Hylab can throttle new server spawns based on CPU/RAM and log resource samples.
Defaults are safe for desktops, but can be overridden:
- `HYLAB_THROTTLE_CPU_PCT` (default 85)
- `HYLAB_THROTTLE_MEM_PCT` (default 80)
- `HYLAB_THROTTLE_INTERVAL_MS` (default 1000)
- `HYLAB_RESOURCE_SAMPLE_INTERVAL_SEC` (default 2)
- `HYLAB_RESOURCE_LOG_INTERVAL_SEC` (default 5; set 0 to disable)
- `HYLAB_PROCESS_PRIORITY` (default BelowNormal; use Normal for max speed)
- `HYLAB_CPU_AFFINITY` (default all; use round-robin or mask:0xF)

## Thin clone (save disk)
By default, Hylab copies the entire server template per test. You can enable
thin cloning to hardlink static files and junction static folders, reducing
disk usage dramatically.

Config keys:
- `ThinCloneEnabled` (default false)
- `ThinCloneWritableDirs` (default: mods, logs, universe, .cache)
- `ThinCloneWritableFiles` (default: config.json, permissions.json, whitelist.json, bans.json)

Env overrides:
- `HYLAB_THIN_CLONE=true`
- `HYLAB_THIN_CLONE_WRITABLE_DIRS="mods,logs,universe,.cache"`
- `HYLAB_THIN_CLONE_WRITABLE_FILES="config.json,permissions.json,whitelist.json,bans.json"`

Note: thin clone only works when `TemplateDir` and `RunsDir` are on the same drive.

## Run retention (auto-cleanup)
You can automatically delete old runs to avoid disk bloat:
- `RunRetentionCount` (keep N most recent runs; 0 disables)
- `RunRetentionDays` (delete runs older than N days; 0 disables)

Env overrides:
- `HYLAB_RUN_RETENTION_COUNT=20`
- `HYLAB_RUN_RETENTION_DAYS=7`

## Stage-ahead (prefetch)
Stage test folders ahead of time so boot start is fast and overlaps with
existing server runs:
- `StageAheadCount` (default: MaxParallel)
- `HYLAB_STAGE_AHEAD_COUNT=4`

## Log size cap
Limit stdout/stderr size per test to avoid giant logs:
- `LogMaxBytes` (default: 10485760)
- `HYLAB_LOG_MAX_BYTES=10485760`

## Prune pass/skip artifacts (smallest runs)
Delete heavy folders for passing or skipped tests, while keeping the AI index
and mod lists:
- `PrunePassArtifacts` (default false)
- `PruneSkipArtifacts` (default false)
- `HYLAB_PRUNE_PASS=true`
- `HYLAB_PRUNE_SKIP=true`

## Boot-time adaptive backoff
Automatically reduce parallelism if average boot time increases:
- `BootTimeAdaptiveEnabled` (default true)
- `BootTimeSampleWindow` (default 6)
- `BootTimeHighSec` / `BootTimeLowSec` (defaults derived from BootTimeout)
- `HYLAB_BOOT_TIME_ADAPTIVE=true`
- `HYLAB_BOOT_TIME_WINDOW=6`
- `HYLAB_BOOT_TIME_HIGH=90`
- `HYLAB_BOOT_TIME_LOW=30`

## Adaptive parallelism (smart spikes)
Hylab can automatically lower or raise parallelism based on CPU/RAM:
- `HYLAB_ADAPTIVE_ENABLED` (default true)
- `HYLAB_ADAPTIVE_MIN_PARALLEL` (default 1)
- `HYLAB_ADAPTIVE_MAX_PARALLEL` (default MaxParallel)
- `HYLAB_ADAPTIVE_SAMPLE_WINDOW` (moving average samples, default 5)
- `HYLAB_ADAPTIVE_SPIKE_PCT` / `HYLAB_ADAPTIVE_SPIKE_HOLD_SEC` (default 92% / 8s)
- `HYLAB_ADAPTIVE_CPU_HIGH` / `HYLAB_ADAPTIVE_CPU_LOW` (default 80/60)
- `HYLAB_ADAPTIVE_MEM_HIGH` / `HYLAB_ADAPTIVE_MEM_LOW` (default 75/60)
- `HYLAB_ADAPTIVE_STEP_UP` / `HYLAB_ADAPTIVE_STEP_DOWN` (default 1/1)
- `HYLAB_ADAPTIVE_COOLDOWN_SEC` (default 10)

## Trace log (debugging)
Each run writes a JSONL trace log at `reports/trace-<RunId>.jsonl`.
Control verbosity:
- `HYLAB_TRACE_LEVEL` (error|warn|info|debug)
- `HYLAB_DEBUG_TAIL_LINES` (lines captured from stdout/stderr on fail/timeout, default 50)

## Proofcheck strict mode
- `./modlab.ps1 proofcheck -Strict`

## Bisect filter
By default bisect only considers `fail` and `timeout`. You can override:
- `./modlab.ps1 bisect -BisectStatus fail,timeout`
- `./modlab.ps1 bisect -BisectStatus fail`

## Notes
- Uses `--auth-mode offline` for Phase A boot testing
- Uses AOT cache when available
- Tune memory with `Xms` and `Xmx` in config
- Required dependencies from manifests are auto-included in boot/scenario when present.
- Missing dependencies skip fast with a clear reason.

## Status values
Boot/report status values: `pass`, `fail`, `timeout`, `skip` (missing deps).

## Error ignore patterns
Use `ErrorIgnorePatterns` in config to suppress known false positives.
You can also override via env:
- `HYLAB_ERROR_IGNORE="UNUSED LOG ARGUMENTS,Error in scheduler task"`

## Troubleshooting
- AOT cache mismatch: set `UseAOTCache=false` or `HYLAB_USE_AOT=false`.
- Missing dependencies: results will be `skip` (not `fail`); run `deps`.
- False positives: add to `ErrorIgnorePatterns` or `HYLAB_ERROR_IGNORE`.
- Lag/slow boots: lower `MaxParallel`, or tune adaptive thresholds.
- Auth: boot uses `--auth-mode offline`; device flow is needed only if you run authenticated servers.

## Safety and EULA
- Never bundle or redistribute game binaries or assets in repros.
- Treat mods as untrusted code; use least-privilege execution.
- Keep outputs artifact-first and reproducible.

## Contributing and docs
- `paper.md`: architecture, schemas, decisions
- `agents.md`: operational playbook and phase gates
- `references/hytale-server-manual.md`: verified server notes
- `runner-plan.md`: cross-platform runner plan
Update these when CLI contracts or schemas change.

## Full beta run (safe, chunked)
```powershell
$env:JAVA_HOME="C:\Program Files\Java\jdk-25.0.2"
$env:PATH="$env:JAVA_HOME\bin;$env:PATH"
$env:HYLAB_MAX_PARALLEL="2"
$env:HYLAB_BOOT_TIMEOUT_SECONDS="120"
.\modlab.ps1 deps
.\modlab.ps1 scan
.\modlab.ps1 plan
.\modlab.ps1 boot -RunId 20260203-fullbeta -StartIndex 0 -Count 20
.\modlab.ps1 boot -RunId 20260203-fullbeta -StartIndex 20 -Count 20
.\modlab.ps1 report -RunId 20260203-fullbeta
```

