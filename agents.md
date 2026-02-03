# Hylab Agent Guide (Comprehensive)

## Purpose
This file is the operational companion to `paper.md` and `README.md`. It
translates the thesis into a dense, actionable playbook for humans or AI
agents. It should be sufficient to continue work without re-deriving context.

## Sources of Truth
- `paper.md` for architecture, requirements, schemas, and policy.
- `README.md` for current CLI usage.
- `modlab.ps1` for current runtime behavior.
- `config/hylab.json` for local defaults and paths (ignored in git).
- `config/hylab.example.json` for shareable defaults.
- Local-only: `skills/` and `dist/` may exist in dev environments.

## Current Repository Snapshot (2026-02-02)
- Implemented commands: `scan`, `plan`, `boot`, `join`, `report`, `proofcheck`, `bisect`, `repro`, `scenario`, `deps`.
- Runtime: PowerShell script and JSON config.
- Directories: `config/`, `runs/`, `reports/`, `repros/`, `logs/`.
- Open gaps: join client automation (requires external join command), asset lane runtime checks, cross-platform runner core, CI templates.

## Core Principles (Non-Negotiable)
- Determinism: same inputs and seed must yield same outputs.
- Evidence: every result is linked to logs and artifacts.
- Minimal footprint: do not patch server or client binaries.
- Fail fast, isolate faster: shrink failing sets quickly.
- Portable by default: parity across Windows, Linux, macOS.
- Compliance first: never ship game binaries or proprietary assets.

## Non-Goals and Safety
- Do not redistribute or package game binaries or assets in repro bundles.
- Do not alter the user's mods in-place.
- Do not assume client-side modding exists.
- Do not rely on unstable log patterns without version pinning.

## Operational Definitions
- RunId: unique identifier for a run (timestamp-based).
- TestId: index of a plan entry within a run.
- Lane: a test category with explicit entry and success criteria.
- Evidence: logs, config snapshot, plan, and matched patterns.
- Repro: a minimal bundle that can be replayed with one command.

## Pipeline Overview (Artifact-First)
1) Scan -> `mods.json`, `mods.csv`
2) Plan -> `plan.json` with coverage metrics
3) Execute -> `runs/<runId>/test-XXXX/` with logs
4) Analyze -> results JSON and metrics
5) Isolate -> minimal failing mod set
6) Report -> CSV/JSON/JUnit/summary

## CLI Contract (Minimum)
Required commands:
- `scan`: inventory mods, output `mods.json` and `mods.csv`.
- `plan`: generate `plan.json` with coverage.
- `boot`: execute plan, output boot report CSV.
- `join`: optional authenticated join tests via `JoinCommand`.
- `report`: summarize results and export summary outputs.
- `bisect`: minimize failing mod sets.
- `repro`: package EULA-safe repro bundle.
- `proofcheck`: static and runtime validation rules.

Required flags:
- `--config`, `--parallel`, `--xmx`, `--xms`, `--seed`, `--group-size`,
  `--limit`, `--lane`, `--run-id`, `--out`, `--json`, `--csv`, `--junit`, `--strict`.
Optional flags:
- `--start-index`, `--count` for chunked boot runs.

Exit codes:
- 0: success
- 1: test failures
- 2: config/runtime errors

## Config Contract (Current Defaults)
Key defaults from `config/hylab.json`:
- PortStart 5520, PortEnd 5535, MaxParallel 8
- Xmx 2G, Xms 256M, BootTimeoutSeconds 180
- ReadyPatterns: Listening on, Server started, Ready
- ErrorPatterns: Exception, \bERROR\b, \bFATAL\b, OutOfMemoryError
- PairwiseGroupSize 10, PairwiseTriesPerGroup 200, PairwiseSeed 1337

Validation rules:
- PortEnd >= PortStart
- Paths must exist or be creatable
- AssetsZip must be readable

## Server Requirements (from Hytale Server Manual)
- Java 25 required (Adoptium recommended).
- Minimum 4GB RAM; monitor CPU/RAM and tune `-Xmx`.
- Protocol: QUIC over UDP (default port 5520).
- AOT cache improves boot: `-XX:AOTCache=HytaleServer.aot`.
- Disable Sentry during mod development: `--disable-sentry`.
- Server files can be copied from launcher install or downloaded via CLI.
  - Launcher paths:
    - Windows: `%appdata%\Hytale\install\release\package\game\latest`
    - Linux: `$XDG_DATA_HOME/Hytale/install/release/package/game/latest`
    - macOS: `~/Application Support/Hytale/install/release/package/game/latest`
  - Downloader CLI:
    - `./hytale-downloader`
    - `./hytale-downloader -print-version`
    - `./hytale-downloader -version`
    - `./hytale-downloader -check-update`
    - `./hytale-downloader -download-path game.zip`
    - `./hytale-downloader -patchline pre-release`
    - `./hytale-downloader -skip-update-check`

## Runtime Behavior (Current)
`modlab.ps1 boot`:
- Copies a server template into each test folder.
- Adds mods into `server/mods`.
- Runs Java with `-XX:AOTCache=HytaleServer.aot`, `--auth-mode offline`,
  `--assets <AssetsZip>`, `--bind 0.0.0.0:<port>`, `--disable-sentry`.
- Monitors logs for ReadyPatterns/ErrorPatterns.
Authentication notes:
- First-time server auth uses device flow: `/auth login device`.
- Auth is required for service APIs (manual notes 100-server limit per license).

## Networking Notes
- Firewall rules must allow UDP on the bind port (default 5520).
- Port forwarding must be UDP (not TCP).

## Lanes and Criteria
Boot lane:
- Entry: valid plan and mods available.
- Success: ready pattern observed.
- Failure: error pattern or timeout.

Scenario lane:
- Entry: boot succeeded or ready state observed.
- Success: all DSL steps pass.
- Failure: step failure or timeout.

Join lane:
- Entry: server listening and network enabled.
- Success: client handshake completes.
- Failure: handshake error or timeout.

Asset validation lane:
- Entry: mod inventory exists.
- Success: referenced assets exist and parse.
- Failure: missing/invalid assets.

## Data Contracts (Must Remain Stable)
- `mods.json`: mod inventory with hashes.
- `plan.json`: plan metadata, tests, and coverage metrics.
- `results.json`: per-test status and duration.
- `proof.json`: proof ledger of validation rules.
- `repro/manifest.json`: repro bundle manifest.

## Proofcheck (Baseline Rules)
- manifest.required
- entrypoint.class
- dependency.closure
- asset.format
- runtime.registration
- runtime.ready

## Isolation and Repro (Baseline)
- Use ddmin-style reduction with caching.
- Output minimal failing mod set.
- Generate repro bundle without game binaries or assets.
- Repro must run with one command and include checksums.

## Reporting Requirements
- CSV for per-test rows.
- JSON for machine parsing.
- JUnit XML for CI gating.
- Markdown summary for humans.
- Every report must include runId/testId and schema version.

## Compatibility Matrix
- Dimensions: server version, mod pack, platform, lane.
- Tiers: Smoke, Standard, Extended.
- Gate policy: Tier 1 required for any mod pack, Tier 2 for server updates,
  Tier 3 weekly/nightly.

## Performance Targets and Budgets
- 100 mods pairwise group size 10 in < 30 minutes on 16-core machine.
- Plan generation for 200 mods in < 10 seconds.
- Repro bundle creation < 60 seconds.
- Flag if P95 boot time regresses > 20 percent.

## Security and Compliance
- Mods are untrusted code; prefer sandbox or least-privileged execution.
- Default bind should be localhost unless configured.
- Redact tokens and user paths in logs.
- Never include game binaries or assets in repro bundles.

## Cross-Platform Rules
- Normalize paths and avoid case-sensitive assumptions.
- Handle process trees and timeouts consistently.
- Keep wrappers thin: PowerShell and Bash.
- Maintain parity tests across Windows and Linux.

## Testing Strategy
- Unit: planner determinism, log classifier, config validation.
- Integration: boot lane on known-good mod set, proofcheck on test plugin.
- Regression: known failing mod combos and report snapshots.

## Phase Plan and Gates
Phase 1:
- scan/plan/boot stable on two environments
- report command outputs JSON + CSV
- config schema validated on load

Phase 2:
- proofcheck ledger with >= 3 rules
- bisect produces minimal failing set
- repro bundle passes EULA-safe checklist

Phase 3:
- cross-platform runner core in use
- scenario lane executes a basic script
- CI templates published

Phase 4:
- performance baselines recorded
- plugin system documented
- compatibility matrix published

## Roles and Deliverables
Architect:
- Maintain `paper.md` contracts and decision log.
- Approve schema/CLI changes and non-goals.

Core Runner Engineer:
- Cross-platform runner core and process management.
- Template/cache behavior, port allocation, parallelism.

Planner Engineer:
- Deterministic planning and coverage metrics.
- Plan schema compliance and tests.

Analyzer/Reporter:
- Log taxonomy, classification, and report outputs.
- JUnit and Markdown summary generation.

Proofcheck Engineer:
- Static validation rules and runtime probes.
- Proof ledger format and evidence links.

Isolation/Repro Engineer:
- ddmin-based reduction and caching.
- Repro bundle creation and validation.

DX/CLI/Docs:
- CLI help, examples, and error messages.
- Documentation updates for any contract changes.

CI/Operations:
- CI templates and artifact retention.
- Release packaging, versioning, and health checks.

## Definition of Done (Per Feature)
- CLI contract updated and documented.
- Schema changes validated and versioned.
- Outputs include JSON plus at least one human-readable format.
- Logs and artifacts linked to runId/testId.
- At least one reproducible test exists for new logic.

## Change Control
- Keep `paper.md` and `README.md` updated when contracts change.
- Record major decisions in the decision log section of `paper.md`.
- Avoid deleting existing artifacts without explicit user request.
