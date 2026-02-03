# Hylab: Comprehensive Plan and Thesis for Automated Hytale Server Mod Testing

## Document Meta
- Version: 0.1
- Status: Living plan and technical thesis
- Date: 2026-02-02
- Owner: Project Lead (Codex)
- Repo Root: <repo-root>
- Audience: mod authors, server operators, QA, CI/CD owners, maintainers

## Abstract
Hylab is an automated test harness for Hytale server mods. It standardizes how
we scan mods, plan coverage, boot servers, detect failures, isolate regressions,
and produce reproducible evidence. The goal is not just to catch crashes; it is
to build confidence in mod ecosystems by making compatibility measurable and
repeatable. This document is a thesis plan: it explains why Hylab exists, how
it works, how it will evolve, and how it should be operated across Windows,
Linux, and macOS. It is intentionally exhaustive so that future contributors,
AIs, and maintainers can re-enter the project without losing institutional
knowledge.

## Table of Contents
1. Vision and Problem Statement
2. Principles and Design Tenets
3. Stakeholders and Personas
4. Use Cases and User Journeys
5. Scope and Non-Goals
6. Assumptions and Constraints
7. Current State of modlab
8. Requirements (Functional and Non-Functional)
9. Architecture Overview
10. Core Components and Responsibilities
11. Data Model and Artifacts
12. Directory Layout and Storage Strategy
13. CLI Design and Command Contract
14. Configuration Schema and Overrides
15. Execution Lifecycle
16. Coverage Planning and Pairwise Strategy
17. Test Lanes and Scenarios
18. Proofcheck (Static and Runtime Validation)
19. Isolation and Bisect Strategy
20. Repro Bundle Format
21. Reporting Formats and Summaries
22. Observability, Telemetry, and Log Taxonomy
23. Performance, Parallelism, and Resource Control
24. Cross-Platform Compatibility Strategy
25. Security, Supply Chain, and Compliance
26. Extensibility and Plugin Model
27. Developer Experience and Workflow
28. CI/CD Integration
29. Release Engineering and Versioning
30. Operations and Maintenance
31. Risk Register and Mitigations
32. Roadmap and Milestones
33. Open Questions
34. Glossary
35. Hytale Modding Model and Policy Constraints
36. Architecture Diagrams
37. JSON Schemas and Data Contracts
38. Scenario DSL Specification
39. Compatibility Matrix Design
40. Evidence and Repro Protocol
41. Security Threat Model
42. Performance Benchmarks
43. Test Matrix and Coverage Policy
44. Decision Log (Key Choices)
45. API and Integration Surface
46. Governance and Contribution Guidelines
47. Migration and Backward Compatibility
48. Glossary Extension (Operational Terms)
49. Implementation Checklist and Phase Gates
50. Tooling and Dependency Strategy
51. Data Retention and Privacy
52. Reliability and Resilience Practices
53. Testing and Validation Strategy (Expanded)
54. Roadmap Risks and Mitigation Gates
55. Asset Validation Guidelines
56. Mod Metadata and Dependency Resolution
57. Appendices (Examples and Templates)

# 1. Vision and Problem Statement
Hylab exists to solve a specific and persistent problem: mod compatibility on
a rapidly evolving server platform is hard to measure and harder to reproduce.
Without automation, mod authors and server operators rely on anecdotal reports,
random load orders, and painful manual trials. Hylab turns that chaos into a
controlled experiment. It automates the boring parts (boot tests, coverage
planning, log scanning) and standardizes the evidence we use when something
breaks.

## 1.1 Problem Surface
Compatibility failures are multi-causal and slippery. The core issues are:

- Interaction complexity: failures often appear only when two or more mods
  interact in a specific order.
- Environment drift: server version, Java runtime, config, OS, and assets
  change over time and alter behavior.
- Observability gaps: logs are inconsistent and often lack clear readiness
  markers or error fingerprints.
- Repro gaps: failures are reported without a minimal mod set or a complete
  execution recipe.
- Time cost: manual trial and error wastes hours and discourages rigorous
  testing.

## 1.2 Vision
The high-level vision is to make compatibility measurable, repeatable, and
communicable. Hylab should:

- Make compatibility measurable, not subjective.
- Make failures reproducible with minimal effort.
- Make regression detection fast enough for daily use.
- Make the system easy to run locally and in CI.
- Make platform differences explicit and testable.
- Create evidence that is safe to share and easy to interpret.

## 1.3 Desired Outcomes
When Hylab is complete, a mod author should be able to run a single command and
get a compatibility report that can be shared with confidence. A server
operator should be able to verify that a new mod set boots and runs without
breaking existing content. A CI system should be able to prove, on every build,
that critical mod combinations still pass.

Success looks like:

- A failing mod set can be minimized to a repro within minutes, not hours.
- A report includes the exact server build, config, seed, and mod hashes.
- The same plan yields the same results across supported platforms.
- A compatibility matrix can be generated and compared across versions.

# 2. Principles and Design Tenets
Hylab should be built on a set of explicit engineering principles. These
tenets are non-negotiable and should guide every design decision, from CLI
behavior to output formats.

## 2.1 Determinism Over Magic
- A test run should be repeatable when given the same inputs, seed, and
  environment.
- All randomness must be seeded and recorded.
- Any nondeterminism (timeouts, race conditions) should be captured in output.

## 2.2 Evidence Over Opinions
- Every failure must include raw logs, a plan reference, and a reproducible
  command line.
- Reports must link directly to test artifacts.
- “Pass” is always backed by evidence, not just the absence of errors.

## 2.3 Minimal Footprint
- Do not patch or modify the server binary.
- Do not require client-side modifications.
- Keep runtime dependencies small and explicit.

## 2.4 Fail Fast, Isolate Faster
- Detect boot failures quickly and terminate cleanly.
- Use bisect and delta debugging to shrink failing sets.
- Prefer shorter, more numerous tests to a few long, opaque runs.

## 2.5 Portable by Default
- The core runner should behave the same on Windows, Linux, and macOS.
- OS-specific behavior belongs in wrappers, not core logic.
- Path handling, encoding, and process management must be parity-tested.

## 2.6 Clear Contracts
- Every CLI command, output file, and config key should have a stable
  definition and versioned schema.
- Backward compatibility should be preserved for at least one minor release.
- Breaking changes must be explicit and documented.

## 2.7 Safety and Compliance
- Never ship game binaries or proprietary assets in repro bundles.
- Treat mods as untrusted code.
- Provide guardrails for network exposure and sandboxed execution.

# 3. Stakeholders and Personas
Hylab serves multiple audiences with different goals and constraints. These
roles inform feature priorities and reporting formats.

## 3.1 Primary Stakeholders
- Mod authors: want fast feedback and evidence when a mod causes a failure.
- Server operators: need confidence that a mod pack will boot and remain stable.
- QA and integration testers: need repeatable coverage across mod combinations.
- CI/CD owners: need machine-readable pass or fail artifacts and stable runners.
- Maintainers: need a system that is easy to extend and safe to change.

## 3.2 Secondary Stakeholders
- Community support: needs repro bundles to triage issues quickly.
- Security reviewers: need supply-chain visibility and hashable artifacts.
- Tooling integrators: need APIs and stable output schemas.

## 3.3 Representative Personas
- Solo mod author: runs Hylab locally on Windows, wants quick boot failures and
  minimal repro bundles to share.
- Small server admin: runs Hylab weekly on Linux and wants easy reports.
- Large mod pack team: runs Hylab in CI with scheduled matrix testing.
- Tool maintainer: wants clean configs and predictable outputs.

## 3.4 Persona Pain Points
- Mod authors: unclear repros, unclear load order effects, limited time.
- Operators: fear of downtime, too many variables, lack of confidence in
  compatibility updates.
- QA: needs deterministic runs and evidence to file bugs.
- CI owners: needs predictable run time and machine-readable outputs.

# 4. Use Cases and User Journeys
This section defines the practical workflows Hylab must support and the
artifacts they require.

## 4.1 Key Use Cases
- Boot compatibility smoke test for a mod pack after any change.
- Pairwise coverage of mods to catch interaction failures.
- Automated isolation of a failing mod combination.
- Regression testing for server version updates.
- Baseline performance checks (boot time and memory).
- Validation of mod manifests and asset packaging.
- CI gating for critical mod packs before release.
- Nightly extended matrix runs for ecosystem stability tracking.

## 4.2 Example Journeys
- Mod author: scan mods -> plan coverage -> boot tests -> view report -> bisect
  -> generate repro -> share with maintainer.
- Server operator: scan mods -> run boot tests -> verify boot pass -> run
  scenario tests -> export report -> archive.
- CI system: run hylab on push -> publish JUnit + CSV -> fail build if critical
  lane fails -> upload repro bundle.

## 4.3 Expected Artifacts Per Journey
Mod author:
- mods.json, plan.json, boot report, repro bundle

Server operator:
- boot report, scenario summary, run metadata

CI system:
- junit.xml, JSON report, logs bundle, repro bundle (on fail)

# 5. Scope and Non-Goals
This section clarifies what Hylab will and will not attempt to do.

## 5.1 In-Scope
- Server-side mod compatibility testing.
- Boot and readiness detection.
- Coverage planning (pairwise and prioritized).
- Log scanning and failure classification.
- Repro bundle generation and reporting.
- Optional client join tests (headless or scripted).
- Static validation of mod manifests and assets.
- CI/CD integrations and standard report formats.

## 5.2 Out-of-Scope (For Now)
- Full gameplay correctness testing at scale.
- Client-side mod testing (if client mods exist later, treat separately).
- Distribution or hosting of game binaries.
- Automated reverse engineering of the server.
- Large-scale player simulation beyond small bot joins.

## 5.3 Boundary Conditions
- Hylab does not enforce content quality or design intent.
- Hylab does not guarantee absence of bugs, only compatibility signals.
- Hylab prioritizes reproducibility over exhaustive gameplay validation.

# 6. Assumptions and Constraints
The system is built on explicit assumptions and must respect operational and
legal constraints.

## 6.1 Assumptions
- The Hytale server runs as a Java process and can be launched from CLI.
- Mods are stored as jars or zip-style packages and can be copied into a
  server mods directory.
- A ready state can be detected from log output or server status probes.
- Server assets can be provided via a local Assets.zip path.
- Offline auth mode is available for fast boot testing.

## 6.2 Constraints
- No redistribution of game binaries or assets in repro bundles.
- Tests must be safe for offline auth mode where appropriate.
- The system must tolerate partial or broken mods without corrupting global
  state.
- The tooling must be operable by non-developers using documented commands.
- All outputs must be created within the configured WorkDir.

## 6.3 Compliance Boundaries
- Repro bundles must be safe to share.
- Logs must avoid leaking secrets or local filesystem paths unless required.

# 7. Current State of modlab
This is the current baseline in the repository as of 2026-02-02:

## 7.1 Implemented Commands
- `scan`: inventory mods and write `mods.json` and `mods.csv`.
- `plan`: generate pairwise test groups and write `plan.json`.
- `boot`: execute plan groups and write a boot CSV report.
- `join`: optional authenticated join tests via `JoinCommand`.
- `report`: summarize results to CSV/JSON/JUnit/Markdown.
- `proofcheck`: static validation and proof ledger.
- `bisect`: ddmin-style isolation of failing sets.
- `repro`: EULA-safe repro bundles with manifests.
- `scenario`: run scripted steps against a booted server.
- `deps`: dependency preflight reports.

## 7.2 What the Script Does Today
- Scans a ModsSource directory and lists `.jar` and `.zip` mods.
- Generates pairwise coverage groups with random sampling.
- Boots the server for each group using offline auth and log pattern matching.
- Optionally runs authenticated join tests via a user-supplied join command.
- Captures stdout/stderr into per-test log folders and JSONL trace logs.
- Writes CSV/JSON/JUnit/Markdown reports for results and summaries.

## 7.3 Current Config Keys
ServerRoot, AssetsZip, ModsSource, WorkDir, TemplateDir, RunsDir, ReportsDir,
ReprosDir, LogsDir, PortStart, PortEnd, MaxParallel, Xmx, Xms,
BootTimeoutSeconds, JoinCommand, JoinTimeoutSeconds, JoinAuthMode,
ReadyPatterns, ErrorPatterns, PairwiseGroupSize, PairwiseTriesPerGroup,
PairwiseSeed, plus adaptive throttling and trace settings.

## 7.4 Gaps and Missing Features
- Join lane depends on an external client command for actual connection tests.
- No cross-platform core (PowerShell is Windows-focused).
- Asset lane runtime checks still minimal.
- CI templates and parity tests still missing.

# 8. Requirements (Functional and Non-Functional)
Requirements are the baseline contract for any implementation.

## 8.1 Functional Requirements
- Scan mods and build a canonical inventory with hashes, metadata, and sizes.
- Plan coverage across mod combinations using pairwise and weighted strategies.
- Boot test mod sets in parallel with deterministic timeouts.
- Detect readiness and failures from logs and or probes.
- Isolate failing mod sets to a minimal repro.
- Generate reproducible bundles without including game binaries.
- Output machine-readable results (JSON, CSV, JUnit) and human summaries.
- Support multiple test lanes beyond boot (scenario, join, asset checks).
- Allow config overrides via CLI flags and environment variables.
- Maintain a compatibility matrix across server versions.
- Provide a stable API for external tooling (report parsing).

## 8.2 Non-Functional Requirements
- Determinism: given same inputs, outputs should match within tolerance.
- Portability: Windows, Linux, and macOS must work with minimal delta.
- Performance: boot tests should scale across cores with predictable limits.
- Safety: never overwrite or delete user mods outside controlled directories.
- Observability: every failure must be debuggable with logs and artifacts.
- Maintainability: modular design with clear responsibilities.
- Stability: graceful handling of server crashes and timeouts.
- Compliance: EULA-safe repro bundles with no game binaries.

## 8.3 Quality Targets (Initial)
- Boot lane should finish for 100 mods within 30 minutes on a 16-core system.
- Plan generation should handle 200+ mods within 10 seconds.
- Repro bundle generation should finish within 60 seconds.
- Crash classification should identify top 20 failure signatures.
- At least 95% of tests should produce a clear ready/error/timeout state.

## 8.4 Server Runtime Requirements (Manual Summary)
These are required to run a dedicated Hytale server and should be treated as
baseline assumptions for Hylab environments.
- Java 25 runtime required (Adoptium recommended).
- Minimum 4GB RAM; tune heap with `-Xmx`.
- QUIC over UDP; default port 5520 (bind with `--bind`).
- First-time auth via device flow: `/auth login device`.
- Recommended launch: `-XX:AOTCache=HytaleServer.aot`.
- Disable crash reporting for dev: `--disable-sentry`.
- Server files can be copied from launcher install or downloaded via CLI.

Reference: `references/hytale-server-manual.md`.

# 9. Architecture Overview
Hylab is a pipeline system with distinct stages. Each stage consumes inputs and
produces artifacts that can be replayed. The architecture is intentionally
artifact-first: every stage writes structured outputs so later stages can be
rerun without repeating earlier steps.

## 9.1 High-Level Flow
- Intake: scan mods, build inventory.
- Plan: generate coverage groups and test definitions.
- Execute: launch servers for each group.
- Analyze: classify logs, detect readiness and failures.
- Isolate: reduce failing sets to minimal repro.
- Report: produce summaries and export artifacts.

## 9.2 Stage Boundaries and Contracts
Each stage has an explicit contract:
- Inputs are immutable artifacts from prior stages.
- Outputs are versioned and stored under WorkDir.
- Stages are idempotent when re-run with identical inputs.

## 9.3 Artifact-First Design
Key design idea: every stage is a pure function over inputs where possible, and
every output is saved to disk for audit and replay. This enables:
- Reproducible bug reports (re-run a stage with the same artifacts).
- Partial replays (skip scan/plan and rerun execute).
- Traceability (every report links to exact inputs).

## 9.4 Concurrency Model
- The planner is single-threaded but deterministic.
- The runner is parallelized by test group with a MaxParallel cap.
- The analyzer runs per test as logs are collected.
- Isolation runs are prioritized and may execute with reduced parallelism.

## 9.5 Failure Handling
- Every failure is categorized (error, timeout, crash).
- Processes are terminated cleanly; orphaned processes are detected.
- Failures produce evidence artifacts, not just exit codes.

## 9.6 Caching Strategy
- Template server copies are cached per server version.
- AOT cache and derived assets are reused where safe.
- Hash-based caching avoids rerunning identical mod sets.

# 10. Core Components and Responsibilities
Each component has a narrow, testable responsibility. This prevents cross-cutting
logic and makes it easier to replace or extend parts of the system.

## 10.1 CLI Front-End
- Parses arguments and maps them to commands.
- Provides user-facing help and error messages.
- Emits consistent exit codes for CI.

## 10.2 Config System
- Loads JSON config and applies overrides.
- Validates schema version and required fields.
- Emits a config snapshot in each run.

## 10.3 Inventory Scanner
- Discovers mods and assets.
- Computes hashes and metadata.
- Produces `mods.json` and `mods.csv`.
- Optional dependency preflight (`deps`) produces `deps.json` and `deps.md`.

## 10.4 Planner
- Generates deterministic coverage groups.
- Emits coverage metrics and plan metadata.
- Supports pairwise, weighted, and directed sets.

## 10.5 Runner
- Prepares templates and test sandboxes.
- Launches server instances with configured JVM args.
- Captures stdout/stderr and monitors readiness.

## 10.6 Analyzer
- Parses logs and classifies failures.
- Extracts metrics and timing.
- Produces structured result records.

## 10.7 Proofcheck Engine
- Runs static validation rules on mods and assets.
- Executes runtime probes for registration checks.
- Writes proof ledger outputs with evidence.

## 10.8 Isolator
- Minimizes failing mod sets with delta debugging.
- Reuses cached results to avoid reruns.
- Records isolation steps and final minimal set.

## 10.9 Reporter
- Writes CSV, JSON, JUnit XML, and Markdown summaries.
- Links results to runId/testId and artifacts.
- Provides top-failure and trend summaries.

## 10.10 Repro Packer
- Builds EULA-safe repro bundles.
- Includes config, plan, logs, and mod hashes.
- Excludes game binaries and proprietary assets.

## 10.11 Cache Manager
- Stores template copies and AOT cache.
- Deduplicates artifacts by hash.
- Supports retention policies and cleanup.

# 11. Data Model and Artifacts
The data model is deliberately simple and stable. Each entity should be easy
to serialize and include enough metadata for replay and analysis.

## 11.1 Core Entities
- Mod: {name, path, size, hash, type, manifest}
- ModSet: ordered set of Mod references with optional weights.
- Plan: {generatedAt, type, groupSize, seed, mods, tests}
- TestCase: {id, modIndices, lanes, configOverrides}
- Run: {runId, startTime, configSnapshot, planRef}
- Result: {testId, status, duration, pattern, logRef, metrics}
- Proof: {modId, ruleId, status, evidence, timestamp}
- ReproBundle: {bundleId, manifest, contents}

## 11.2 Identifiers and Stability
- `runId` should be unique and time-based for ordering.
- `testId` should be stable within a run and map to plan index.
- `mod hash` should be content-based (e.g., SHA-256).

## 11.3 Artifact Catalogue
- `mods.json` and `mods.csv`
- `plan.json`
- `runs/<runId>/test-XXXX/` (server, logs, metrics)
- `reports/*.csv`, `reports/*.json`, `reports/*.md`, `junit.xml`
- `repros/<bundleId>/` or `.zip`
- `cache/*` (AOT, templates, hashes)

## 11.4 Traceability Guarantees
- Every report entry links to a runId and testId.
- Every repro bundle includes a plan reference.
- Every proof ledger links to a mod hash and rule id.

# 12. Directory Layout and Storage Strategy
Directory layout is designed to isolate artifacts, preserve reproducibility,
and prevent accidental changes to user data.

## 12.1 Recommended Layout
- modlab/
  - config/
  - templates/
  - runs/
  - reports/
  - repros/
  - logs/
  - cache/ (new)
  - tools/ (optional helper scripts)

## 12.2 Storage Rules
- All generated artifacts live under WorkDir to avoid touching user data.
- Templates are copied from ServerRoot and cached with version tagging.
- Runs are immutable; never overwrite an existing run folder.
- Reports should include a pointer to the runId for traceability.

## 12.3 Retention and Cleanup
- Retention policies should be configurable by days or total size.
- Cache may be pruned independently of runs and reports.
- Repro bundles should be retained longer by default.

# 13. CLI Design and Command Contract
The CLI is the public contract for Hylab. It should be stable, versioned, and
explicit about outputs.

## 13.1 Command Families
- scan: inventory mods and assets
- plan: generate coverage plan
- boot: run boot lane
- proofcheck: run static validation
- run: execute one or more lanes
- report: summarize and export results
- bisect: isolate failing mod set
- repro: package a repro bundle
- clean: prune old runs or caches
- doctor: environment sanity checks
- config: print effective config

## 13.2 Core Flags
--config, --parallel, --xmx, --xms, --seed, --group-size, --limit, --lane,
--run-id, --out, --json, --csv, --junit, --strict, --start-index, --count

## 13.3 Output Defaults
- `scan` writes `mods.json` and `mods.csv`.
- `plan` writes `plan.json`.
- `boot` writes a boot report CSV and per-test logs.
- `report` writes summary outputs in configured formats.

## 13.4 Compatibility and Wrappers
- Provide thin wrappers: modlab.ps1 (Windows) and modlab.sh (Unix).
- The core runner should be a cross-platform binary or Python entrypoint.

## 13.5 Return Codes
- 0 for success
- 1 for failed tests
- 2 for config or runtime errors

# 14. Configuration Schema and Overrides
Config is a JSON file with explicit defaults. It must be validated, versioned,
and overridable in a predictable way.

## 14.1 Precedence Order
1) CLI flags
2) Environment variables
3) Config file
4) Built-in defaults

## 14.2 Key Sections
- paths: ServerRoot, AssetsZip, ModsSource, WorkDir, TemplateDir, RunsDir,
  ReportsDir, ReprosDir, LogsDir, CacheDir, DepOverridesPath, ExcludesPath
- ports: PortStart, PortEnd, PortStrategy
- runtime: MaxParallel, Xmx, Xms, BootTimeoutSeconds
- planning: PairwiseGroupSize, PairwiseTriesPerGroup, PairwiseSeed
- detection: ReadyPatterns, ErrorPatterns, ReadyTimeoutSeconds
- lanes: boot, scenario, join, asset, proofcheck
- reporting: Formats, RetentionDays, IncludeLogs
- safety: AllowNetwork, AllowExternalProcesses
- dependency controls: dep overrides file, excludes list

## 14.3 Schema Versioning
- Embed a schema version in config and reports.
- Validate on load; fail fast on unknown required fields.
- Provide migration notes for deprecated keys.

## 14.4 Validation Rules
- Paths must exist where required.
- Port ranges must be valid and non-overlapping.
- MaxParallel must be > 0.
- BootTimeoutSeconds must be >= 0.

# 15. Execution Lifecycle
Each test run follows a consistent lifecycle. These steps should be visible in
logs and trace output to make debugging and replay straightforward.

## 15.1 Lifecycle Steps
1) Prepare
   - Validate config
   - Ensure directories
   - Load mod inventory and hashes
2) Stage
   - Create plan
   - Prepare templates and caches
3) Execute
   - Launch server instances
   - Apply mod sets and config overrides
   - Monitor logs and probes
4) Analyze
   - Classify logs and patterns
   - Record metrics and status
5) Isolate (optional)
   - Minimize failing mod set
6) Report
   - Export reports and summaries
7) Cleanup
   - Stop processes
   - Prune temp files if configured

## 15.2 Lifecycle Logging
- Every step should emit a start and end marker.
- Failures should be tagged to the step in which they occurred.
- The run summary should include the duration of each step.

## 15.3 Determinism Notes
- Plan generation should occur before execution to preserve deterministic order.
- Any randomization should be recorded in run metadata.

# 16. Coverage Planning and Pairwise Strategy
Pairwise testing is a starting point, not the final goal. The planner should
support multiple strategies and provide explicit coverage metrics.

## 16.1 Planning Strategies
- Pairwise random groups (current approach).
- Weighted pairwise (prioritize mods with higher risk).
- Directed sets (explicit mod combos).
- Rolling windows (for ordered load tests).
- Regression sets (known risky combinations).

## 16.2 Coverage Metrics
- Percentage of pairs covered.
- Frequency of each mod across groups.
- Group size distribution.
- Coverage gap list (pairs not covered).

## 16.3 Determinism and Seeds
- Planner should be deterministic given the same seed and inputs.
- Seed and parameters must be recorded in plan metadata.

## 16.4 Priority Heuristics (Optional)
- Weight newer or frequently failing mods higher.
- Increase coverage around mods with many dependencies.

# 17. Test Lanes and Scenarios
Hylab should treat each lane as a first-class artifact with explicit rules and
outputs.

## 17.1 Lane Definitions
- Boot: server starts, reaches ready state, no fatal errors.
- Asset validation: verify mod assets and manifests without booting the server.
- Scenario: scripted commands or events to verify basic behavior.
- Join: client connection or bot join to verify network handshake (via JoinCommand).
- Load: multiple bots or repeated joins to test stability.
- Regression: specific known mod combos or past failures.

## 17.2 Lane Contracts
Each lane should define:
- Entry criteria
- Timeouts
- Success criteria
- Failure signatures
- Output artifacts

## 17.3 Scenario DSL (Planned)
- Define a minimal JSON/YAML step model:
  - wait-for-ready
  - run-command
  - expect-log
  - expect-state
- Keep it small and stable; complex logic belongs in plugins.

# 18. Proofcheck (Static and Runtime Validation)
Proofcheck is a rule-based validator that produces a compatibility proof. It
exists to answer: “Does this mod set comply with expected structure and basic
runtime behavior?”

## 18.1 Static Proof
- Validate manifest fields and dependency closure.
- Verify entrypoint class structure and required interfaces.
- Check for forbidden paths or missing assets.
- Compute hashes and produce a signature map.

## 18.2 Runtime Proof
- Boot with a probe plugin or built-in commands.
- Verify that mods register commands and event listeners.
- Confirm that expected log messages are present.
- Capture timing and memory snapshots.

## 18.3 Proof Ledger
- A JSON file that records each rule, status, evidence, and timestamps.
- Used as a compatibility certificate across runs.
- Linked to mod hashes and runId for traceability.

## 18.4 Rule Categories
- manifest.required
- entrypoint.class
- dependency.closure
- asset.format
- runtime.registration
- runtime.ready

# 19. Isolation and Bisect Strategy
Isolation is the bridge between it failed and here is the culprit.

## 19.1 Primary Techniques
- Delta debugging: recursively split mod sets until minimal failing set found.
- Weighted removal: drop low-risk mods first.
- Cache-aware isolation: reuse prior results to avoid redundant boots.
- Multi-failure tracking: if multiple failures exist, tag each signature.

## 19.2 Isolation Outputs
- Minimal mod set
- Evidence logs
- Proven failing seed and config

## 19.3 Isolation Rules
- Stop when a minimal set is found that still fails.
- Record each reduction step for auditability.
- Preserve and reuse all logs for failed attempts.

# 20. Repro Bundle Format
Repro bundles must be safe to share and reproduce. They are the primary
handoff artifact for debugging and issue reporting.

## 20.1 Contents
- Repro manifest (JSON)
- Mod list with hashes
- Config snapshot
- Plan and test definition
- Logs and reports
- Optional scripts for reproduction

## 20.2 Exclusions
- Game binaries
- Proprietary assets
- Personal data

## 20.3 Integrity and Versioning
- Bundles should be versioned and include a checksum for integrity.
- Each bundle should include a runId and testId reference.

# 21. Reporting Formats and Summaries
Reports are the interface between Hylab and humans. They must be consistent,
readable, and machine-friendly.

## 21.1 Formats
- CSV for quick filtering and spreadsheets.
- JSON for machine parsing.
- JUnit XML for CI systems.
- Markdown summary for humans.

## 21.2 Summary Content
- Run metadata (runId, server version, mod count).
- Pass or fail counts by lane.
- Top failure signatures.
- Time and resource stats.
- Links to repro bundles.

## 21.3 Reporting Guarantees
- Every report should include schema version and generation time.
- Reports must link back to runId and testId.
- JSON format should be stable across minor versions.

# 22. Observability, Telemetry, and Log Taxonomy
Hylab should capture enough telemetry to make failures actionable without
overwhelming users.

## 22.1 What to Capture
- Raw stdout and stderr.
- Classified log events.
- Timeline of lifecycle steps.
- Resource metrics (CPU, memory, disk, ports).

## 22.2 Log Taxonomy
- READY: readiness or listening events.
- ERROR: known error patterns.
- CRASH: process exit before ready.
- TIMEOUT: exceeded boot timeout.
- WARNING: non-fatal issues.
- INFO: lifecycle markers.

## 22.3 Metrics Storage
- Metrics should be stored as JSON.
- Optional export to Prometheus or similar tooling.

## 22.4 Evidence Requirements
- Each failure should include the matched pattern and a log excerpt.
- Telemetry should include timestamps for each lifecycle step.

# 23. Performance, Parallelism, and Resource Control
Parallelism is essential but dangerous without limits. Hylab must balance speed
against system stability.

## 23.1 Parallelism Strategy
- MaxParallel cap from config.
- Port ranges with collision handling.
- Staggered startup to reduce IO spikes.
- Backoff when error rate spikes.

## 23.2 Resource Controls
- CPU and memory throttling when needed.
- Explicit JVM Xms/Xmx configuration.
- Optional per-run limits for CI environments.
- Resource sampling to CSV for run diagnostics.
- Optional process priority and CPU affinity tuning for desktop safety.

## 23.3 Performance Features
- Warm server template with cached data.
- AOT cache reuse and template reuse.
- Hash-based caching for mod sets.
- Optional dry-run mode for planner only.

# 24. Cross-Platform Compatibility Strategy
A cross-platform runner is required for full adoption. Parity between OSes is
the baseline, not an optional feature.

## 24.1 Key Rules
- Use OS-agnostic path handling and normalize separators.
- Avoid case-sensitive assumptions in filenames.
- Use Unicode-safe and ASCII-safe modes where needed.
- Avoid OS-specific process flags unless wrapped.
- Provide wrappers: modlab.ps1, modlab.sh, and a direct binary.

## 24.2 Compatibility Targets
- Windows 10+ with PowerShell
- Linux (Ubuntu or Debian)
- macOS (Intel and Apple Silicon)

## 24.3 Parity Testing
- Run a small boot plan on each OS.
- Compare plan outputs and report schemas for equality.
- Validate that ready/error patterns behave consistently.

# 25. Security, Supply Chain, and Compliance
Security is a core requirement, not an optional feature. Hylab handles
untrusted code and produces artifacts that may be shared externally.

## 25.1 Policies
- Never ship game binaries or proprietary assets in repros.
- Treat mods as untrusted code.
- Optional sandbox or container execution for high-risk runs.
- Provide a supply chain report with hashes and sources.
- Mask any secrets in logs (tokens, credentials).

## 25.2 Compliance Checklist
- EULA-safe repro packaging
- No network exposure unless configured
- Audit trail for mod sources and versions

## 25.3 Threat Model Notes
- Mods can execute arbitrary code; assume malicious inputs.
- Logs can contain sensitive paths or tokens; sanitize by default.

# 26. Extensibility and Plugin Model
Hylab should be extensible without forking. The plugin model should be safe,
versioned, and optional.

## 26.1 Extension Points
- Custom lanes
- Custom proofcheck rules
- Custom log classifiers
- External reporters (Slack, email, dashboards)

## 26.2 Implementation Guidelines
- Plugin folder loaded at runtime.
- Explicit interface definitions and version checks.
- Fail-safe isolation for plugin errors.
- Plugins should not bypass safety constraints.

## 26.3 Compatibility Rules
- Core schema changes should be reflected in plugin interfaces.
- Plugins must declare supported schema and runner versions.

# 27. Developer Experience and Workflow
A great tool is only useful if it is easy to use. DX should be considered a
first-class feature.

## 27.1 DX Goals
- Single command to run a full lane with defaults.
- Clear error messages and actionable tips.
- Auto-generated repro bundles with one flag.
- Watch mode for rapid local iteration.

## 27.2 Suggested Workflows
- modlab scan -> plan -> boot -> report
- modlab proofcheck --strict before publishing mods
- modlab bisect --from runId

## 27.3 Onboarding Aids
- `doctor` command to validate environment and paths.
- `config` command to print effective config.
- Example configs in `config/`.

# 28. CI/CD Integration
CI should treat Hylab as a first-class testing stage.

## 28.1 CI Guidelines
- Use deterministic seeds and pinned configs.
- Archive reports and repro bundles as artifacts.
- Fail builds on critical lane failures.
- Provide nightly extended coverage runs.

## 28.2 CI Outputs
- junit.xml for test results
- summary.md for human review
- logs.zip for debugging

## 28.3 Recommended CI Tiers
- PR smoke: small plan, short timeout.
- Main branch: medium plan, strict gating.
- Nightly: large plan and extended scenarios.

# 29. Release Engineering and Versioning
Hylab versions should be explicit and predictable.

## 29.1 Versioning
- Semantic versioning for CLI and schema.
- Schema version embedded in reports.
- Migration scripts for config changes.

## 29.2 Distribution
- Cross-platform releases
- Checksums for binaries
- Versioned changelogs

## 29.3 Release Validation
- Run a smoke plan before each release.
- Validate schema compatibility with prior configs.

# 30. Operations and Maintenance
Long-term use requires maintenance practices that keep storage and reliability
in check.

## 30.1 Ops Guidelines
- Retention policy for runs and logs.
- Disk usage monitoring.
- Periodic cache cleanup.
- Health checks for CI runners.

## 30.2 Maintenance Tasks
- Review readiness/error patterns after server updates.
- Rotate old repro bundles to cold storage if needed.
- Audit mod hash catalogs for drift.

# 31. Risk Register and Mitigations
This section tracks the highest-impact risks and the mitigation plan for each.

## 31.1 Platform and Compatibility Risks
- Server updates change log patterns.
  Mitigation: versioned patterns and readiness probes.
- Cross-platform inconsistencies.
  Mitigation: unified runner core and parity tests.
- Java runtime changes affect startup behavior.
  Mitigation: pin Java versions in CI and record runtime in reports.

## 31.2 Execution and Stability Risks
- Mods with side effects corrupt test data.
  Mitigation: immutable templates and per-run sandbox.
- Excessive runtime due to large mod sets.
  Mitigation: weighted planning and sampling.
- Runaway processes or orphaned servers.
  Mitigation: process tree tracking and forced cleanup.

## 31.3 Data and Security Risks
- Repro bundles accidentally include proprietary assets.
  Mitigation: bundle allowlist and automated scans.
- Logs contain sensitive paths or tokens.
  Mitigation: log sanitization and masking rules.

## 31.4 Process and Maintenance Risks
- Schema drift breaks older configs.
  Mitigation: versioned schemas and migration notes.
- Plugin incompatibilities cause failures.
  Mitigation: strict plugin version checks and fail-safe isolation.

# 32. Roadmap and Milestones
The roadmap is staged to deliver quick wins first, then expand capability.

## Phase 1 (Now)
- Stabilize scan, plan, and boot.
- Add report command and structured outputs.
- Add config schema validation.

## Phase 2
- Proofcheck engine with static validation.
- Isolation and bisect.
- Repro bundles.

## Phase 3
- Cross-platform runner core.
- Scenario lane and join lane.
- CI integration templates.

## Phase 4
- Load testing and performance baselines.
- Plugin system and external reporting.
- Public compatibility matrix.

## Milestone Criteria
- Each phase is complete when outputs are versioned and tested.
- Each phase should include at least one end-to-end demo run.

# 33. Open Questions
These are unresolved decisions that affect architecture and implementation.

- What are the official server readiness signals and how stable are they?
- What is the minimal client join mechanism for automation?
- Which mod metadata fields are required versus optional?
- How should we handle mod dependency resolution conflicts?
- What is the best default for MaxParallel on low-end systems?
- What is the expected format for mod version constraints?

# 34. Glossary
- Mod: a package that changes server behavior or content.
- Lane: a category of test with specific criteria.
- Plan: a set of test cases generated from a mod inventory.
- Repro bundle: a package that allows repeating a failure.
- Proofcheck: the static and runtime validation engine.
- RunId: unique identifier for a test run.
- TestId: index of a test case within a plan/run.

# 35. Hytale Modding Model and Policy Constraints
This section summarizes official Hytale guidance that directly shapes Hylab's
design and compliance posture.

## 35.1 Server-Side-First Model
Hytale treats “server” as the authority even in singleplayer (a local server),
and official guidance emphasizes server-side-first modding with a stable,
unmodded client so players can join modded servers without separate client
packs. citeturn1view0

## 35.2 Mod Content Categories
Officially described modding content falls into four major categories: server
plugins (Java .jar), data assets (JSON), art assets (sounds/models/textures),
and save files (worlds/prefabs). citeturn1view0

## 35.3 Policy and Compliance Constraints
The EULA allows creating and sharing mods (including monetization under
conditions) but prohibits distributing original game files, and server
operators must follow baseline rules with additional obligations for listed
servers. citeturn0search1turn0search0

Implications for Hylab:
- Treat server-side testing as the primary lane.
- Never bundle or redistribute game binaries/assets in repros.
- Provide compliance-safe defaults and evidence artifacts suitable for server
  operators.

# 36. Architecture Diagrams
These diagrams illustrate Hylab's pipeline and component interactions. They are
intentionally simple and stable so the architecture remains easy to explain.

## 36.1 Pipeline Flow (Artifacts First)
```text
Mods/Assets
   |
   v
[Scan] -> mods.json/mods.csv
   |
   v
[Plan] -> plan.json
   |
   v
[Execute] -> runs/<runId>/test-XXXX/{server,logs}
   |
   v
[Analyze] -> results.json, metrics.json
   |
   v
[Isolate] -> minimal mod set, repro manifest
   |
   v
[Report] -> csv/json/junit/summary.md
```

## 36.2 Component Interaction
```text
CLI
 |-- Config System
 |-- Inventory Scanner
 |-- Planner
 |-- Runner
 |-- Analyzer
 |-- Proofcheck
 |-- Isolator
 |-- Reporter
 |-- Repro Packer
 |-- Cache Manager
```

# 37. JSON Schemas and Data Contracts
These schemas define the minimum contract between Hylab components and external
tools. This section is intentionally dense so it can serve as a spec.

## 37.1 Versioning Rules
- Every JSON artifact includes `SchemaVersion` (e.g., "1.0.0").
- SchemaVersion changes only when required fields or semantics change.
- Tools should accept unknown fields when SchemaVersion matches.

## 37.2 Config Schema (full, v1)
Notes:
- Paths are environment-specific and must be absolute.
- Defaults shown match `config/hylab.json` where applicable.
- PortEnd must be >= PortStart (enforced in validation logic).

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "HylabConfig",
  "type": "object",
  "required": ["SchemaVersion", "ServerRoot", "AssetsZip", "ModsSource", "WorkDir"],
  "properties": {
    "SchemaVersion": { "type": "string", "minLength": 1, "default": "1.0.0" },
    "ServerRoot": { "type": "string", "minLength": 1 },
    "AssetsZip": { "type": "string", "minLength": 1 },
    "ModsSource": { "type": "string", "minLength": 1 },
    "WorkDir": { "type": "string", "minLength": 1 },
    "TemplateDir": { "type": "string", "minLength": 1 },
    "RunsDir": { "type": "string", "minLength": 1 },
    "ReportsDir": { "type": "string", "minLength": 1 },
    "ReprosDir": { "type": "string", "minLength": 1 },
    "LogsDir": { "type": "string", "minLength": 1 },
    "CacheDir": { "type": "string", "minLength": 1 },
    "DepOverridesPath": { "type": "string", "minLength": 1 },
    "ExcludesPath": { "type": "string", "minLength": 1 },
    "UseAOTCache": { "type": "boolean", "default": true },
    "ResourceSampleIntervalSec": { "type": "integer", "minimum": 0, "default": 2 },
    "TraceLogLevel": { "type": "string", "default": "info" },
    "DebugTailLines": { "type": "integer", "minimum": 0, "default": 50 },
    "PortStart": { "type": "integer", "minimum": 1, "default": 5520 },
    "PortEnd": { "type": "integer", "minimum": 1, "default": 5535 },
    "MaxParallel": { "type": "integer", "minimum": 1, "default": 8 },
    "Xmx": { "type": "string", "pattern": "^\\d+(K|M|G)$", "default": "2G" },
    "Xms": { "type": "string", "pattern": "^\\d+(K|M|G)$", "default": "256M" },
    "AdaptiveThrottleEnabled": { "type": "boolean", "default": true },
    "AdaptiveMinParallel": { "type": "integer", "minimum": 1, "default": 1 },
    "AdaptiveMaxParallel": { "type": "integer", "minimum": 1, "default": 8 },
    "AdaptiveSampleWindow": { "type": "integer", "minimum": 1, "default": 5 },
    "AdaptiveSpikePct": { "type": "integer", "minimum": 0, "maximum": 100, "default": 92 },
    "AdaptiveSpikeHoldSec": { "type": "integer", "minimum": 0, "default": 8 },
    "AdaptiveCpuHighPct": { "type": "integer", "minimum": 0, "maximum": 100, "default": 80 },
    "AdaptiveCpuLowPct": { "type": "integer", "minimum": 0, "maximum": 100, "default": 60 },
    "AdaptiveMemHighPct": { "type": "integer", "minimum": 0, "maximum": 100, "default": 75 },
    "AdaptiveMemLowPct": { "type": "integer", "minimum": 0, "maximum": 100, "default": 60 },
    "AdaptiveStepUp": { "type": "integer", "minimum": 0, "default": 1 },
    "AdaptiveStepDown": { "type": "integer", "minimum": 0, "default": 1 },
    "AdaptiveCooldownSec": { "type": "integer", "minimum": 0, "default": 10 },
    "ThrottleCpuPct": { "type": "integer", "minimum": 0, "maximum": 100, "default": 85 },
    "ThrottleMemPct": { "type": "integer", "minimum": 0, "maximum": 100, "default": 80 },
    "ThrottleCheckIntervalMs": { "type": "integer", "minimum": 0, "default": 1000 },
    "ResourceLogIntervalSec": { "type": "integer", "minimum": 0, "default": 5 },
    "ProcessPriority": { "type": "string", "default": "BelowNormal" },
    "CpuAffinityMode": { "type": "string", "default": "all" },
    "BootTimeoutSeconds": { "type": "integer", "minimum": 0, "default": 180 },
    "JoinCommand": { "type": "string", "default": "" },
    "JoinTimeoutSeconds": { "type": "integer", "minimum": 0, "default": 60 },
    "JoinAuthMode": { "type": "string", "default": "authenticated" },
    "ThinCloneEnabled": { "type": "boolean", "default": false },
    "ThinCloneWritableDirs": { "type": "array", "items": { "type": "string" } },
    "ThinCloneWritableFiles": { "type": "array", "items": { "type": "string" } },
    "RunRetentionCount": { "type": "integer", "minimum": 0, "default": 0 },
    "RunRetentionDays": { "type": "integer", "minimum": 0, "default": 0 },
    "StageAheadCount": { "type": "integer", "minimum": 1, "default": 4 },
    "LogMaxBytes": { "type": "integer", "minimum": 0, "default": 10485760 },
    "BootTimeAdaptiveEnabled": { "type": "boolean", "default": true },
    "BootTimeSampleWindow": { "type": "integer", "minimum": 1, "default": 6 },
    "BootTimeHighSec": { "type": "integer", "minimum": 0, "default": 90 },
    "BootTimeLowSec": { "type": "integer", "minimum": 0, "default": 30 },
    "PrunePassArtifacts": { "type": "boolean", "default": false },
    "PruneSkipArtifacts": { "type": "boolean", "default": false },
    "ReadyPatterns": {
      "type": "array",
      "items": { "type": "string" },
      "default": ["Listening on", "Server started", "Ready"]
    },
    "ErrorPatterns": {
      "type": "array",
      "items": { "type": "string" },
      "default": ["Exception", "\\bERROR\\b", "\\bFATAL\\b", "OutOfMemoryError"]
    },
    "ErrorIgnorePatterns": {
      "type": "array",
      "items": { "type": "string" },
      "default": ["UNUSED LOG ARGUMENTS", "Error in scheduler task"]
    },
    "PairwiseGroupSize": { "type": "integer", "minimum": 2, "default": 10 },
    "PairwiseTriesPerGroup": { "type": "integer", "minimum": 1, "default": 200 },
    "PairwiseSeed": { "type": "integer", "default": 1337 }
  },
  "additionalProperties": false
}
```

Validation rules (logic beyond JSON Schema):
- PortEnd must be >= PortStart.
- Directories must exist or be creatable.
- AssetsZip must point to a readable file.
- DepOverridesPath/ExcludesPath must be absolute when set; files are optional.
- ResourceSampleIntervalSec must be >= 0.
- DebugTailLines must be >= 0.
- TraceLogLevel in {error,warn,info,debug}.
- ErrorIgnorePatterns must be a string array when present.
- ThrottleCpuPct/ThrottleMemPct must be 0..100 (0 disables the threshold).
- AdaptiveMinParallel <= AdaptiveMaxParallel.
- Adaptive*Pct values must be 0..100.
- AdaptiveSampleWindow must be >= 1.
- AdaptiveSpikeHoldSec must be >= 0.
- ProcessPriority must be one of: Idle, BelowNormal, Normal, AboveNormal, High.
- CpuAffinityMode must be all, round-robin, or mask:0xF.
- JoinTimeoutSeconds must be >= 0.
- JoinAuthMode must be one of: offline, authenticated.
- RunRetentionCount must be >= 0.
- RunRetentionDays must be >= 0.
- StageAheadCount must be >= 1.
- LogMaxBytes must be >= 0.
- BootTimeSampleWindow must be >= 1.
- BootTimeHighSec and BootTimeLowSec must be >= 0.
- PrunePassArtifacts and PruneSkipArtifacts must be boolean.

## 37.3 Inventory Schema (mods.json)
This is the output of `scan`. Current script emits a subset; hashes are optional.

```json
{
  "SchemaVersion": "1.0.0",
  "GeneratedAt": "2026-02-02T12:00:00Z",
  "Mods": [
    {
      "Name": "ExampleMod.jar",
      "Path": "C:\\Path\\To\\Mods\\ExampleMod.jar",
      "Size": 123456,
      "Extension": ".jar",
      "Hash": "sha256:..."
    }
  ]
}
```

## 37.4 Plan Schema (v1)
```json
{
  "SchemaVersion": "1.0.0",
  "GeneratedAt": "2026-02-02T12:00:00Z",
  "Type": "pairwise",
  "GroupSize": 10,
  "Seed": 1337,
  "Mods": [{ "Name": "A.jar" }, { "Name": "B.jar" }],
  "Coverage": {
    "TotalPairs": 1,
    "CoveredPairs": 1,
    "CoveragePct": 100.0
  },
  "Tests": [[0, 1]]
}
```

Validation rules:
- Each test array length must equal GroupSize.
- Mod indices must be valid and unique within a test.

## 37.5 Result Schema (per test)
```json
{
  "TestId": 0,
  "Status": "pass",
  "DurationSec": 42,
  "Pattern": "Ready",
  "LogDir": "runs/20260202-120000/test-0000",
  "Port": 5520
}
```

Status values:
- pass: ready pattern seen
- fail: error pattern seen
- timeout: BootTimeoutSeconds exceeded
- skip: missing dependency detected

## 37.6 Proof Ledger Schema (v1)
```json
{
  "SchemaVersion": "1.0.0",
  "GeneratedAt": "2026-02-02T12:00:00Z",
  "Proofs": [
    {
      "Mod": "ExampleMod.jar",
      "Hash": "sha256:...",
      "Overall": "pass",
      "Rules": [
        {
          "Id": "manifest.required",
          "Status": "pass",
          "Severity": "error",
          "Evidence": "manifest.json present"
        }
      ]
    }
  ]
}
```

## 37.7 Repro Manifest Schema (v1)
```json
{
  "SchemaVersion": "1.0.0",
  "BundleId": "repro-20260202-001",
  "CreatedAt": "2026-02-02T12:00:00Z",
  "ServerVersion": "1.0.0",
  "Mods": [{ "Name": "ExampleMod.jar", "Hash": "sha256:..." }],
  "ConfigSnapshotPath": "repro/config.json",
  "PlanPath": "repro/plan.json",
  "Logs": ["repro/logs/stdout.log", "repro/logs/stderr.log"],
  "Lanes": ["boot"],
  "Notes": "Fails after Ready"
}
```

## 37.8 Dependency Preflight Schema (deps.json)
```json
{
  "SchemaVersion": "1.0.0",
  "GeneratedAt": "2026-02-02T12:00:00Z",
  "Summary": {
    "TotalMods": 100,
    "ModsWithMissing": 5,
    "ModsWithUndeclared": 2,
    "MissingUnique": ["Example:CoreLib"]
  },
  "Mods": [
    {
      "Mod": "ExampleMod.jar",
      "Id": "Example:Mod",
      "DeclaredDependencies": ["Example:CoreLib"],
      "EffectiveDependencies": ["Example:CoreLib"],
      "MissingDependencies": ["Example:CoreLib"],
      "UndeclaredHardDependencies": []
    }
  ]
}
```

# 38. Scenario DSL Specification
This section defines a minimal, stable DSL for scenario testing. The DSL is
designed for deterministic execution and simple validation.

## 38.1 Goals
- Express basic actions (commands, waits, and log assertions).
- Be deterministic and easy to replay.
- Avoid embedding complex logic (use plugins for advanced cases).
- Provide clear, machine-readable failure reasons.

## 38.2 Core Step Types (v1)
1) `wait-for-ready`
   - Fields: `timeoutSeconds` (int, required)
   - Behavior: wait until a ready pattern or probe signal is observed.

2) `run-command`
   - Fields: `command` (string, required)
   - Behavior: send a server command and capture output.

3) `expect-log`
   - Fields: `pattern` (string, required), `timeoutSeconds` (int, optional)
   - Behavior: wait for a log line matching `pattern`.

4) `sleep`
   - Fields: `seconds` (int, required)
   - Behavior: wait without additional checks.

## 38.3 Scenario Schema (v1)
```json
{
  "type": "object",
  "required": ["version", "steps"],
  "properties": {
    "version": { "type": "integer", "enum": [1] },
    "steps": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "required": ["type"],
        "properties": {
          "type": { "type": "string", "enum": ["wait-for-ready", "run-command", "expect-log", "sleep"] },
          "timeoutSeconds": { "type": "integer", "minimum": 0 },
          "command": { "type": "string" },
          "pattern": { "type": "string" },
          "seconds": { "type": "integer", "minimum": 0 }
        },
        "additionalProperties": false
      }
    }
  },
  "additionalProperties": false
}
```

## 38.4 Example Scenario (YAML)
```yaml
version: 1
steps:
  - type: wait-for-ready
    timeoutSeconds: 120
  - type: run-command
    command: "list-mods"
  - type: expect-log
    pattern: "Loaded 5 mods"
    timeoutSeconds: 15
  - type: sleep
    seconds: 2
```

## 38.5 Execution Rules
- Steps execute strictly in order.
- If a step fails, the scenario fails with the step index and reason.
- `expect-log` must match at least one log line or fail on timeout.
- `run-command` should capture output even on failure.

## 38.6 Failure Output (example)
```json
{
  "ScenarioId": "smoke-001",
  "StepIndex": 2,
  "StepType": "expect-log",
  "Status": "fail",
  "Reason": "timeout",
  "Pattern": "Loaded 5 mods"
}
```

# 39. Compatibility Matrix Design
The compatibility matrix is the long-term memory of Hylab. It tracks results
across server versions, mod sets, lanes, and platforms.

## 39.1 Matrix Dimensions (Required)
- Server version/build (string)
- Mod set (hash or named pack)
- Platform (Windows/Linux/macOS)
- Lane (boot, scenario, join)
- Run timestamp (for time series)

## 39.2 Storage Model
- Store results as time-series snapshots.
- Keep one “latest” snapshot per version, mod set, lane, and platform.
- Record deltas when a mod set changes.
- Provide a stable JSON export for dashboards.

## 39.3 Matrix Entry Schema (v1)
```json
{
  "SchemaVersion": "1.0.0",
  "ServerVersion": "1.0.0",
  "ModPackId": "pack-abc123",
  "ModPackHash": "sha256:...",
  "Platform": "windows",
  "Lane": "boot",
  "RunId": "20260202-120000",
  "Status": "pass",
  "DurationSec": 1800,
  "PassCount": 38,
  "FailCount": 4,
  "TimeoutCount": 0,
  "TopFailure": "OutOfMemoryError"
}
```

## 39.4 Aggregation Rules
- Status = fail if any critical lane fails.
- Status = warn if only non-critical failures exist.
- Retain last N snapshots per mod pack per version (configurable).

## 39.5 Output Use Cases
- Compare regressions across server updates.
- Validate mod pack compatibility across platforms.
- Provide compatibility dashboards for community and CI.

# 40. Evidence and Repro Protocol
This protocol defines the minimum evidence required to consider a failure
reproducible and actionable.

## 40.1 Required Evidence (Must Have)
- RunId and TestId
- Full mod list with hashes
- Config snapshot (resolved overrides)
- Logs (stdout/stderr) with timestamps
- Failure classification and matched pattern
- Server version and Java runtime version

## 40.2 Optional Evidence (Nice to Have)
- Resource metrics (CPU/memory)
- Proof ledger (if proofcheck ran)
- Scenario outputs
- AOT cache usage indicator

## 40.3 Repro Structure (Required Files)
- `repro/manifest.json`
- `repro/config.json`
- `repro/plan.json`
- `repro/logs/stdout.log`
- `repro/logs/stderr.log`

## 40.4 Repro Validation Rules
- Repro should execute with a single command.
- Repro must not include game binaries or proprietary assets.
- Repro must include versioned schema and tool version.
- Repro must include a checksum of bundled files.

## 40.5 Repro Command (Example)
```bash
modlab boot --config repro/config.json --plan repro/plan.json
```

# 41. Security Threat Model
Hylab executes untrusted mod code, so its threat model must be explicit and
operationalized.

## 41.1 Threats (Concrete)
- Malicious mods executing arbitrary code (file deletion, exfiltration).
- Logs leaking sensitive paths, tokens, or personal data.
- Repro bundles accidentally including proprietary assets.
- Exposed server ports in shared or public environments.
- Dependency poisoning via untrusted mod sources.

## 41.2 Security Controls (Baseline)
- Treat mods as untrusted; prefer sandbox or container mode for CI.
- Default to bind on localhost unless explicitly configured.
- Mask secrets in logs using pattern-based redaction.
- Enforce allowlists for repro bundle contents.
- Record mod hashes and source paths for audit trails.

## 41.3 Redaction Rules (Minimum)
- Replace tokens matching patterns: `token=...`, `apikey=...`, `Authorization: ...`
- Redact user home paths when possible (e.g., `C:\\Users\\<name>`).
- Provide an opt-in “strict redaction” mode for public reports.

## 41.4 Sandbox/Isolation Options
- Windows: run under least-privileged user.
- Linux: containerized execution with read-only mounts where possible.
- macOS: use sandbox-exec or container wrapper if available.

## 41.5 Residual Risks
- Sandbox may not fully isolate host interactions.
- Log redaction may miss unknown secret patterns.
- Mods may detect sandboxing and behave differently.

# 42. Performance Benchmarks
Benchmarks provide a shared reference for expected performance and resource
usage. They should be updated when server versions change significantly.

## 42.1 Baseline Targets (Initial)
- 100 mods, pairwise group size 10: complete boot lane in < 30 minutes on
  a 16-core machine with SSD.
- Plan generation for 200 mods in < 10 seconds.
- Repro bundle creation in < 60 seconds.

## 42.2 Measurement Method
- Record boot duration per test and overall run duration.
- Capture peak memory usage per server process.
- Report average and P95 boot times.
- Track total CPU time to identify regressions.

## 42.3 Benchmark Artifacts
- `reports/benchmarks.json` with per-run stats.
- `reports/benchmarks.md` summary for humans.

## 42.4 Performance Budgets
- If P95 boot time regresses by > 20%, flag as performance regression.
- If memory usage exceeds Xmx by > 10%, flag as misconfiguration.

# 43. Test Matrix and Coverage Policy
The test matrix defines which combinations of server version, mod packs, lanes,
and platforms must be exercised to claim compatibility.

## 43.1 Matrix Tiers (Explicit)
- Tier 1 (Smoke): 5-10 mods, boot lane only, all platforms.
- Tier 2 (Standard): representative mod pack, boot + scenario lanes.
- Tier 3 (Extended): large mod pack, boot + scenario + join lanes.

## 43.2 Coverage Policy
- Every new mod pack must pass Tier 1.
- Every server version update must pass Tier 2.
- Weekly or nightly runs should execute Tier 3.

## 43.3 Failure Handling
- Platform-specific failures may be quarantined with explicit notes.
- Timeouts should trigger isolation attempts before a full fail.
- If Tier 1 fails, block further tiers until resolved.

## 43.4 Matrix Output Format
- A single JSON summary file listing tiers, results, and timestamps.
- Include per-tier lane statuses and top failure patterns.

# 44. Decision Log (Key Choices)
This log captures high-impact decisions so future contributors understand why
the system looks the way it does.

## 44.1 Artifact-First Pipeline
- Decision: every stage writes artifacts for replay.
- Reason: reproducibility and auditability are core goals.

## 44.2 Server-Side-First Testing
- Decision: treat server boot and behavior as primary signal.
- Reason: official modding direction emphasizes server-side-first.

## 44.3 Pairwise Planning as Baseline
- Decision: use pairwise coverage as default planning strategy.
- Reason: balances coverage and runtime cost for large mod sets.

## 44.4 EULA-Safe Repro Bundles
- Decision: never include game binaries or proprietary assets.
- Reason: compliance and safe sharing.

# 45. API and Integration Surface
This section defines how external tools can integrate with Hylab.

## 45.1 File-Based APIs (Required)
- `mods.json`, `plan.json`, `reports/*.json`, `junit.xml`
- Structured and versioned outputs for parsers.
- Schemas documented in Section 37.

## 45.2 CLI Integration
- Stable exit codes for gating CI:
  - 0: success
  - 1: test failures
  - 2: config/runtime errors
- `--json`, `--csv`, `--junit` for output selection.
- `--run-id` for replay and report retrieval.

## 45.3 Optional Service API (Future)
- HTTP endpoint for submitting plans and retrieving results.
- Webhook integration for CI and dashboards.
- Authentication required for multi-tenant usage.

## 45.4 External Tooling Examples
- CI systems parsing `junit.xml` for gating.
- Dashboards consuming `reports/*.json`.

# 46. Governance and Contribution Guidelines
This section outlines how contributions are proposed, reviewed, and accepted.

## 46.1 Contribution Workflow
- Propose changes via issue or design note.
- Ensure schema or CLI changes include migration notes.
- Require at least one test for core logic changes.
- Update `paper.md` for any contract-level changes.

## 46.2 Review Principles
- Favor backward compatibility when feasible.
- Require evidence for performance or behavioral claims.
- Document any breaking changes in the decision log.

## 46.3 Version Control Hygiene
- Avoid large, opaque changes without context.
- Keep config and schema changes explicit and documented.
- Prefer small, reviewable commits.

# 47. Migration and Backward Compatibility
Changes to schemas, CLI, and artifacts should be predictable and documented.

## 47.1 Compatibility Rules
- Maintain backward compatibility for at least one minor version.
- Provide deprecation warnings before removing keys or flags.
- Keep old report readers working when possible.

## 47.2 Migration Artifacts
- Provide migration notes for each breaking change.
- Offer a simple migration script for config changes.
- Document default changes explicitly.

## 47.3 Versioning Policy
- Bump schema version when required fields change.
- Bump CLI major version for breaking flags or outputs.
- Use semantic versioning for all public artifacts.

# 48. Glossary Extension (Operational Terms)
- Baseline: a known-good run used for comparison.
- Evidence: logs, configs, and artifacts required to reproduce a result.
- Lane Contract: the explicit rules for a test lane.
- Matrix Tier: a predefined coverage level for compatibility testing.
- Probe: a lightweight runtime check used to assert readiness or registration.

# 49. Implementation Checklist and Phase Gates
This checklist defines the minimum bar to complete each phase.

## 49.1 Phase 1 Gate
- scan/plan/boot stable across at least two environments.
- report command outputs JSON + CSV.
- config schema validated on load.
- ready/error patterns verified on at least one real server build.

## 49.2 Phase 2 Gate
- proofcheck emits ledger with at least 3 rules.
- bisect produces a minimal failing set.
- repro bundle passes EULA-safe checklist.
- isolation run uses cached results to reduce runtime.

## 49.3 Phase 3 Gate
- cross-platform runner core in use.
- scenario lane executes a basic script.
- CI templates published.
- parity tests pass across Windows/Linux.

## 49.4 Phase 4 Gate
- performance baselines recorded.
- plugin system documented.
- compatibility matrix published.

# 50. Tooling and Dependency Strategy
This section defines how Hylab should manage its dependencies and tools.

## 50.1 Language and Runtime Choice
- Prefer a single cross-platform core runtime.
- Keep dependencies small and avoid heavy frameworks.
- Avoid runtime features that differ across OSes.

## 50.2 Dependency Policies
- Pin versions for CI determinism.
- Avoid dependencies that require native builds where possible.
- Document any required external tools (Java, zip).
- Prefer widely available libraries with permissive licenses.

## 50.3 Tooling Baseline
- Java 25 runtime for server execution (per Hytale Server Manual).
- Zip tooling for repro bundles.
- Optional JSON Schema validator for config validation.
- Optional log parser library for structured extraction.

# 51. Data Retention and Privacy
Define how long artifacts are kept and how sensitive data is handled.

## 51.1 Retention Defaults
- Logs: 30 days
- Runs: 30 days
- Reports: 90 days
- Repro bundles: 180 days

## 51.2 Privacy Guidelines
- Redact local usernames and tokens in logs.
- Do not include personal data in repro bundles.
- Provide a strict redaction mode for public sharing.

## 51.3 Retention Policy Overrides
- Allow retention policies to be overridden per lane.
- Provide a `clean` command to prune by age and size.

# 52. Reliability and Resilience Practices
This section defines how Hylab should behave under adverse conditions.

## 52.1 Resilience Principles
- Fail fast and surface actionable errors.
- Prefer partial results over total failure.
- Always attempt clean shutdowns.

## 52.2 Recovery Behavior
- Resume runs from last completed test when possible.
- Keep retry counts explicit and capped.
- Record recovery attempts in the run summary.

## 52.3 Retry Policy
- Retry only on transient errors (timeouts, port conflicts).
- Do not retry deterministic failures (known error patterns).

# 53. Testing and Validation Strategy (Expanded)
This expands the earlier testing section with concrete validation steps.

## 53.1 Unit Tests
- Planner determinism with fixed seeds.
- Log pattern classification correctness.
- Config schema validation.
- Port allocation and collision handling.

## 53.2 Integration Tests
- Minimal boot lane run with a known-good mod set.
- Proofcheck with a controlled test plugin.
- Scenario DSL execution on a simple scripted run.

## 53.3 Regression Tests
- Known failing mod combinations must reproduce expected failures.
- Compare report outputs to stored snapshots.
- Verify that repro bundles are EULA-safe.

# 54. Roadmap Risks and Mitigation Gates
This section connects risks to specific phase gates to avoid surprises.

## 54.1 Phase 1 Risks
- Unstable readiness patterns.
  Mitigation: versioned log patterns and a probe option.
- Config drift across environments.
  Mitigation: config snapshot in every run.

## 54.2 Phase 2 Risks
- Bisect algorithm too slow on large sets.
  Mitigation: caching and weighted pruning.
- Proofcheck rules too strict.
  Mitigation: support warn severity with override flags.

## 54.3 Phase 3 Risks
- Cross-platform differences in process control.
  Mitigation: parity test suite before release.
- Scenario DSL complexity creep.
  Mitigation: keep DSL minimal and push complexity to plugins.

## 54.4 Phase 4 Risks
- Performance regressions in large matrices.
  Mitigation: maintain benchmark baselines and budgets.
- Plugin ecosystem fragmentation.
  Mitigation: versioned plugin interfaces and registry guidance.

# 55. Asset Validation Guidelines
Assets are a common source of compatibility issues. Hylab should perform
lightweight checks to detect missing or malformed assets early.

## 55.1 Asset Types
- Models and animations
- Textures and materials
- Sounds
- JSON data assets

## 55.2 Validation Rules (Baseline)
- Required assets referenced by mods must exist.
- Asset file extensions must match expected type.
- JSON assets must parse and validate against schemas.

## 55.3 Evidence
- Asset validation should emit a report listing missing or invalid files.

# 56. Mod Metadata and Dependency Resolution
Mod metadata drives planning and proofcheck behavior. Dependency handling must
be explicit and deterministic.

## 56.1 Metadata Fields (Baseline)
- Name, version, group, entrypoint
- Dependencies and optional dependencies
- Assets included or required

## 56.2 Dependency Resolution Rules
- Required dependencies must be present before execution.
- Optional dependencies may be ignored but should be logged.
- Conflicts should fail fast with clear error messages.

## 56.3 Output
- Include a dependency graph in the plan metadata when available.

# 57. Appendices

## Appendix A: Example config (condensed)
```json
{
  "ServerRoot": "C:\\Path\\To\\Server",
  "AssetsZip": "C:\\Path\\To\\Assets.zip",
  "ModsSource": "C:\\Path\\To\\Mods",
  "WorkDir": "C:\\Path\\To\\modlab",
  "TemplateDir": "C:\\Path\\To\\modlab\\templates\\server",
  "RunsDir": "C:\\Path\\To\\modlab\\runs",
  "ReportsDir": "C:\\Path\\To\\modlab\\reports",
  "ReprosDir": "C:\\Path\\To\\modlab\\repros",
  "LogsDir": "C:\\Path\\To\\modlab\\logs",
  "PortStart": 5520,
  "PortEnd": 5535,
  "MaxParallel": 8,
  "Xmx": "2G",
  "Xms": "256M",
  "BootTimeoutSeconds": 180,
  "ReadyPatterns": ["Listening on", "Server started", "Ready"],
  "ErrorPatterns": ["Exception", "ERROR", "FATAL", "OutOfMemoryError"],
  "PairwiseGroupSize": 10,
  "PairwiseTriesPerGroup": 200,
  "PairwiseSeed": 1337
}
```

## Appendix B: Example plan.json (condensed)
```json
{
  "GeneratedAt": "2026-02-02T12:00:00",
  "Type": "pairwise",
  "GroupSize": 10,
  "Seed": 1337,
  "Mods": [{"Name": "A.jar"}, {"Name": "B.jar"}],
  "Tests": [[0,1],[1,2]]
}
```

## Appendix C: Example boot report (condensed)
```csv
TestId,Status,DurationSec,Pattern,LogDir
0,pass,42,Ready,run/20260202-120000/test-0000
1,fail,12,Exception,run/20260202-120000/test-0001
```

## Appendix D: Example proof ledger (condensed)
```json
{
  "mod": "ExampleMod.jar",
  "rules": [
    {"id": "manifest.required", "status": "pass"},
    {"id": "entrypoint.class", "status": "pass"},
    {"id": "assets.missing", "status": "fail", "evidence": "missing blockymodel"}
  ]
}
```

## Appendix E: Example repro manifest (condensed)
```json
{
  "bundleId": "repro-20260202-001",
  "serverVersion": "1.0.0",
  "mods": [{"name": "ExampleMod.jar", "hash": "abc123"}],
  "config": {"Xmx": "2G"},
  "lanes": ["boot"],
  "notes": "Fails with Exception after ready"
}
```

## Appendix F: Example report summary (condensed)
```md
# Hylab Summary
Run: 2026-02-02T12:00:00
Mods: 42
Pass: 38  Fail: 4  Timeout: 0
Top failure: OutOfMemoryError
Repro bundles: repro-20260202-001.zip
```

## Appendix G: Example CLI usage
```bash
modlab scan --config config/hylab.json
modlab plan --seed 1337 --group-size 8
modlab boot --limit 25
modlab report --run-id 20260202-120000 --junit
```


