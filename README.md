# Hylab

Automated Hytale server mod testing harness.

## Goals
- Fast boot tests (offline auth)
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

## Quick start
1. Set paths in config (coming soon)
2. Run `./modlab.ps1 scan`
3. Run `./modlab.ps1 boot -parallel 8 -xmx 2G`
