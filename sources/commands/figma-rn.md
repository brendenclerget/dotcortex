---
name: figma-rn
description: Build or refine a React Native screen to Figma parity using code-first references.
---

# Figma RN Parity

Use the `figma-rn-parity` skill for this task.

## Expected Arguments
`/figma-rn <figma_component_path> <rn_target_path> [legacy_logic_path]`

## Instructions
1. Determine mode:
   - `BUILD` if target is missing/incomplete.
   - `REFINE` if target exists.
2. Read references:
   - Figma component source path from arguments.
   - RN target file from arguments.
   - Legacy logic source (argument or discovered best match).
   - Design system component/rules docs in repo.
   - Finished calibration screens in repo.
3. Execute full parity pass in one iteration when confidence is high.
4. Preserve existing behavior unless parity requires a real logic correction.
5. Return findings, planned fixes, applied changes, and residual ambiguities.

## Output Shape
- Findings (severity-tagged, one line each)
- Planned Fixes
- Final Report

Arguments: $ARGUMENTS
