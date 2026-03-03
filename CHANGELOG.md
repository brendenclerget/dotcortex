# Changelog

All notable changes to dotcortex (.cortex) are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) with [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.3.0] - 2026-03-02

### Added
- `/commit` command for multi-repo commit workflows
- `thinking-modes` skill re-added with expanded guidance
- `feature-planning` skill with spec templates

### Changed
- Major overhaul of `cortex-init` command (144-line rewrite) — improved scanning and generation
- Expanded `pm-agent` skill significantly (~300 line rewrite) with richer workflow automation
- `cortex-update` improvements for better merge handling
- `ticket-new` and `ticket-breakdown` commands refined

## [1.2.1] - 2026-02-28

### Added
- `/ticket-close` command for archiving completed tickets with knowledge extraction

## [1.2.0] - 2026-02-27

### Removed
- `thinking-modes` skill — became native in Claude Code

### Changed
- Minor cleanup in `cortex-init` and `cortex-update` commands

## [1.1.2] - 2026-02-27

### Changed
- Updated README license badge and footer for Commons Clause

## [1.1.1] - 2026-02-27

### Added
- Commons Clause added to LICENSE to prevent resale/repackaging

## [1.1.0] - 2026-02-27

### Changed
- Renamed project from **localmem** to **dotcortex** (`.cortex`)
- All commands renamed: `localmem-init` → `cortex-init`, `localmem-update` → `cortex-update`
- README, roadmap, docs, scaffolds, and skills updated with new branding
- Polished README with branded SVG logos (dark/light mode) and improved layout

### Added
- `.gitignore`
- Project backlog (`BACKLOG.md`)

## [1.0.0] - 2026-02-27

### Added
- Initial release as **localmem**
- `/localmem-init` bootstrap command (5-phase: scan, interview, research, generate, summary)
- `/localmem-update` with three-way merge checksums
- PM commands: `ticket-new`, `ticket-breakdown`, `ticket-refine`, `next`, `backlog`, `standup`, `pm-sync`
- Skills: `pm-agent`, `backlog-cleanup`, `feature-planning`, `thinking-modes`
- Templates: simple, parent, child, followup tickets
- Scaffolds: `CLAUDE.md` and `MEMORY.md` templates
- `install.sh` for quick setup
- Architecture documentation (`docs/how-it-works.md`)
- MIT license

[Unreleased]: https://github.com/brendenclerget/dotcortex/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/brendenclerget/dotcortex/compare/v1.2.1...v1.3.0
[1.2.1]: https://github.com/brendenclerget/dotcortex/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/brendenclerget/dotcortex/compare/v1.1.2...v1.2.0
[1.1.2]: https://github.com/brendenclerget/dotcortex/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/brendenclerget/dotcortex/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/brendenclerget/dotcortex/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/brendenclerget/dotcortex/releases/tag/v1.0.0
