# Hylab

Automated Hytale server mod testing harness.

## Goals
- Fast boot tests (offline auth)
- Pairwise coverage arrays with targeted isolation
- Minimal repro bundles
- Optional authenticated join tests
- CSV + summary reports

## Layout
modlab/
  bin/
  config/
  runs/
  repros/
  reports/
  logs/

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
5. `./modlab.ps1 report`
6. `./modlab.ps1 proofcheck`
7. `./modlab.ps1 bisect`
8. `./modlab.ps1 repro`
9. `./modlab.ps1 scenario -ScenarioPath .\scenario.json`
10. `./modlab.ps1 deps`

## Quick commands (cheat sheet)
| Task | Command |
| --- | --- |
| Scan mods | `./modlab.ps1 scan` |
| Plan coverage | `./modlab.ps1 plan` |
| Boot tests | `./modlab.ps1 boot` |
| Report | `./modlab.ps1 report -Json -Csv -Junit` |
| Proofcheck | `./modlab.ps1 proofcheck` |
| Bisect | `./modlab.ps1 bisect -BisectStatus fail,timeout` |
| Repro | `./modlab.ps1 repro` |
| Scenario | `./modlab.ps1 scenario -ScenarioPath .\scenario.json` |
| Deps preflight | `./modlab.ps1 deps` |

## Output selection (report)
- `./modlab.ps1 report -Json -Csv -Junit`
- `./modlab.ps1 report -Out .\reports\custom`

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
- `reports/summary-<RunId>.md`: human summary (from `report`)
- `reports/<RunId>.junit.xml`: CI-friendly results (from `report`)
- `reports/trace-<RunId>.jsonl`: structured trace events
- `reports/resource-<RunId>.csv`: CPU/RAM samples

## Config and overrides
- Copy `config/hylab.example.json` to `config/hylab.json` and edit paths.
- Most settings can be overridden with `HYLAB_*` env vars.
- Keep `config/hylab.json` local; do not commit it.
- Contract details and schema notes live in `paper.md`.

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

