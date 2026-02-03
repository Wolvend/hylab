# Hylab Cross-Platform Runner Plan (v1)

## Goal
Extract a portable runner core so Hylab behaves identically on Windows, Linux,
and macOS while keeping `modlab.ps1` and future `modlab.sh` wrappers thin.

## Strategy
1) Define stable interfaces for config, plan, and results.
2) Implement a core runner library (Go/Rust/Python) that:
   - Launches server processes with deterministic args.
   - Captures stdout/stderr to per-test logs.
   - Detects ready/error/timeout states from pattern catalogs.
   - Produces results.json, metrics.json, and junit.xml.
3) Keep wrappers responsible for:
   - Parsing CLI flags.
   - Passing config paths and overrides.
   - Selecting lanes (boot, scenario, proofcheck).

## Proposed Layout
```
core/
  hylab_core/
    config.py
    planner.py
    runner.py
    reporter.py
    schemas/
wrappers/
  modlab.ps1
  modlab.sh
```

## Parity Tests
- Boot lane: same plan + same seed should produce identical result structure.
- Scenario lane: same steps should yield identical pass/fail outcomes.
- Report outputs: JSON schema matches and JUnit counts align.

## Exit Criteria
- Windows and Linux runs match within tolerance on the same mod set.
- One stable release artifact per OS with identical CLI contract.
- Documentation updated and wrappers remain under 200 lines each.
