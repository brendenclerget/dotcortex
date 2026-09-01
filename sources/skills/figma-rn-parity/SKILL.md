---
name: figma-rn-parity
description: Build or refine React Native screens to match Figma using code-first parity, shared design system components, and minimal iteration loops.
---

# Figma -> React Native Parity Skill

## Goal
Deliver production-ready React Native screen parity with Figma using source-code references, not screenshot guessing.

## When to Use
- User asks to build a new RN screen from Figma.
- User asks to refine an existing RN screen to match Figma.
- User asks for high-fidelity visual parity pass (spacing, typography, states, icons).

## Required Inputs
1. Figma component source file path (TSX/code export).
2. RN target file path (existing or to be created).
3. Legacy logic source file/path for behavior parity.
4. Design system docs in the repo (component reference and design rules).
5. Calibration screens in the repo that represent "correct" visual feel.

If any input is missing, proceed with best available context and call out assumptions.

## Mode Selection
1. `BUILD` mode: target screen missing or skeletal.
2. `REFINE` mode: target screen exists and needs parity fixes.
3. Complete implementation and parity in one pass when confidence is high.

## Core Rules
1. Figma TSX is source-of-truth for structure, spacing tokens, and states.
2. Do not use screenshots as source-of-truth values.
3. Apply the repo's design system rules for mobile translation.
4. Prefer shared design system components over one-off screen-local UI.
5. Preserve business logic; change behavior only for true parity/logic gaps.
6. For iOS drift (font weight, vertical rhythm, active color), use explicit inline styles when needed.
7. If utility classes drift visually, use explicit token hex values from theme/design source.

## Workflow
1. Read required references in order.
2. Audit current target against Figma source.
3. Produce findings with concrete current vs target deltas.
4. Plan exact edits.
5. Apply all high-confidence fixes in same pass.
6. Re-audit for shared component impact and regressions.

## Parity Checklist (ordered)
1. Icons (family/name/size/stroke/fill/weight).
2. Colors (text/background/border, including state variants).
3. Radius (web-to-mobile conversion).
4. Typography (size/weight/line density).
5. Inputs/buttons (height, padding, icon/text alignment, placeholder treatment).
6. Spacing (padding/gap/margins).
7. Conditional UI and state-driven variants.
8. Shared component consumer impact.

## Output Format
1. Findings first, one line each:
   `[Severity] <element> — current: <value> | target: <value> | file:line`
2. Planned fixes list.
3. Apply fixes.
4. Final report:
   - Files changed
   - What now matches
   - Remaining ambiguities/blockers
   - Intentionally deferred items

## Guardrails
- Keep edits minimal and targeted in `REFINE`.
- Avoid introducing new design patterns when existing shared components can be reused.
- Do not run app servers unless explicitly requested.
