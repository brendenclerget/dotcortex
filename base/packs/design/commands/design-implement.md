---
name: design-implement
description: Build or refine a React Native screen to parity with an in-repo design artifact using code-first references.
---

# Design Artifact -> RN Parity

Use the `design-implement` skill for this task.

## Expected Arguments
`/design-implement <design_artifact_path> <rn_target_path> [legacy_logic_path]`

## Design artifact contract
The design artifact must already exist in the repo as a stable snapshot referenced by the ticket. If
the user supplies only a URL, save a snapshot into the repo's design-artifacts location and reference
that path from the ticket **before** implementing — never implement off a live link.

## Instructions
1. Determine mode:
   - `BUILD` if target is missing/incomplete.
   - `REFINE` if target exists.
2. Read references:
   - In-repo design artifact source path from arguments.
   - RN target file from arguments.
   - Legacy logic source (argument or discovered best match).
   - Design system component/rules docs in repo.
   - Finished calibration screens in repo.
3. Execute full parity pass in one iteration when confidence is high.
4. Preserve existing behavior unless parity requires a real logic correction.
5. Check shared-component blast radius before editing any shared design system component; report its
   consumers.
6. Return findings, planned fixes, applied changes, and residual ambiguities.

## Output Shape
- Findings (severity-tagged, one line each)
- Planned Fixes
- Final Report

Arguments: $ARGUMENTS
