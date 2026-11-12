# Implementation Plan: Tiko Baseline Healthchecks

## Overview

The Docker Compose healthcheck stanzas, env-var enforcement, and gateway `depends_on` ordering are already in place. The remaining work is: (1) fix the stale script name in `requirements.md`, (2) create the POSIX sh verification script, (3) update the README to mention both check scripts, (4) run a positive test, a negative test, a size/safety check, a live stack proof, and the PowerShell script, and (5) produce a final summary and wait for approval.

## Tasks

- [x] 1. Fix script name in requirements.md
  - [x] 1.1 Update the two stale references in `requirements.md`
    - In Requirement 5 AC 1, change `scripts/check-healthchecks.sh` → `scripts/check-compose-healthchecks.sh`
    - In the Glossary entry for `Verification_Script`, change `scripts/check-healthchecks.sh` → `scripts/check-compose-healthchecks.sh`
    - No other lines in `requirements.md` require changes
    - _Requirements: spec consistency housekeeping_

- [x] 2. Create the POSIX sh verification script
  - [x] 2.1 Write `scripts/check-compose-healthchecks.sh`
    - Create the file at `scripts/check-compose-healthchecks.sh` in the repository root
    - Use exactly the script content specified in design.md §3 (Algorithm + Script block)
    - File must be POSIX sh (`#!/bin/sh`), use `set -eu`, and be ≤ 30 lines
    - The script: `cd`s to the repo root, calls `docker compose --env-file .env.example config --format json`, iterates `service_healthy` dependency targets with `jq`, exits 1 naming any service missing a `healthcheck` block, exits 0 with an `OK:` message if all pass
    - Do NOT create a second `.ps1`; `scripts/check-compose-healthchecks.ps1` already exists
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 3. Update README to mention both check scripts
  - [x] 3.1 Add check-script mention to the "Run locally" section of `README.md`
    - Confirm the existing `docker compose up --build` command is in a fenced code block in that section (do not remove or change it)
    - Add a brief paragraph or sub-section after the startup command that tells developers about the two pre-flight scripts:
      - `sh scripts/check-compose-healthchecks.sh` (Linux / macOS / CI)
      - `powershell -File scripts/check-compose-healthchecks.ps1` (Windows)
    - Description must state these scripts verify that every `service_healthy` dependency declares a healthcheck without starting any containers
    - _Requirements: 4.1, 4.2_

- [ ] 4. Verification
  - [x] 4.1 Run check-compose-healthchecks.sh (positive test)
    - Run `sh scripts/check-compose-healthchecks.sh` from the repo root in Git Bash or WSL
    - Show the raw output and confirm exit code is 0
    - If `jq` is not installed, stop and report that — do not install it or work around it
    - _Requirements: 5.2, 5.3, 5.4, 5.5_
  - [ ] 4.2 Negative test: script catches a missing healthcheck
    - Create a temporary minimal Compose file OUTSIDE the repository (e.g. in `%TEMP%` or `/tmp`) with one service that is listed as a `service_healthy` dependency but defines no `healthcheck` block
    - Run the script against it: `sh scripts/check-compose-healthchecks.sh` with the script's compose invocation pointing at that temporary file (pass via env or a temporary copy of the script — document whichever approach is used)
    - Confirm exit code is 1 and the offending service name appears in the error message
    - Delete the temporary file after the test
    - _Requirements: 5.3, 5.4_
  - [x] 4.3 Confirm script size and no container-starting commands
    - Run `wc -l scripts/check-compose-healthchecks.sh` and confirm the count is 30 or fewer
    - Scan the script for any command that starts a container (`docker run`, `docker compose up`, `docker start`) and confirm none are present
    - _Requirements: 5.1, 5.5_
  - [~] 4.4 Live stack proof: all healthchecks show "healthy"
    - Run `docker compose --env-file .env up -d` from the repo root
    - Wait for services to settle (watch `docker compose ps` until no service shows "starting" or "health: starting")
    - Run `docker compose ps` and show the raw output
    - Every service that defines a healthcheck MUST show status "healthy", not just "running"
    - If any service stays unhealthy: show its logs (`docker compose logs <service>`), show the exact healthcheck command from `docker inspect <container>`, identify the root cause — do NOT increase timeouts as a first response
    - _Requirements: 1.4, 1.5, 2.2, 2.3, 3.4, 3.5_
  - [~] 4.5 Run the PowerShell script and show its exit code
    - Run `powershell -File scripts/check-compose-healthchecks.ps1`
    - Show the raw output and confirm exit code is 0
    - _Requirements: 5.2, 5.3, 5.4_

- [ ] 5. Final summary and approval gate
  - [~] 5.1 List every file changed or created
    - Produce a table: file path | change type (created / modified) | which task produced it
    - Include any file changed that was NOT in the plan (flag those explicitly)
    - Stop and wait for user approval before starting any other spec item
    - _Requirements: all_

## Notes

- Task 1 is a spec housekeeping fix; it does not affect runtime behaviour
- Task 4.1 and 4.5 require `jq` and `powershell` respectively to be on `PATH`; if either is absent, stop and report it — do not install or work around
- Task 4.2 creates and deletes a temporary file outside the repository; nothing in the repo is modified by that task
- Task 4.4 starts the live stack with `.env` (not `.env.example`) — a real `.env` with filled credentials must exist before running this task
- Both `.sh` and `.ps1` scripts must co-exist; they are companions for different platforms
- Do not start any other spec item until task 5.1 is complete and the user has approved

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1"] },
    { "id": 1, "tasks": ["3.1", "4.1", "4.2", "4.3"] },
    { "id": 2, "tasks": ["4.4", "4.5"] },
    { "id": 3, "tasks": ["5.1"] }
  ]
}
```
