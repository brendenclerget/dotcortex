---
name: cortex-update
description: Check for and apply updates from the dotcortex repository while preserving user customizations
---

# cortex-update: Update Managed Files

Update dotcortex-managed commands, skills, and templates from the latest upstream release while preserving user customizations.

## Process

### Step 1: Read Config

Read `.dotcortex/config.json` from the project root.

If `.dotcortex/config.json` does not exist, check for legacy markers:
- `.claude/.dotcortex.json`
- `.claude/.localmem.json`
- `.dotcortex/install-info.json` with migration markers

If any legacy marker exists, detect a legacy install and ask the user to choose:
1. Run `install.sh --with-migrations ...` then re-run `/cortex-update`
2. Run `/cortex-init` in augment mode to rebuild canonical layout

If none exist, stop and tell the user to run `/cortex-init` first.

Extract:
- `source` — GitHub repo URL
- `version` — currently installed version tag
- `config.prefix` — ticket prefix (e.g., "APP")
- `config.tools` — enabled tool views (e.g., `["claude", "codex"]`)
- `config.structure_mode` — `single_project` or `org_connected`
- `config.org` — org settings when connected (`repo`, `project_key`, optional flags)
- `managed_files` — map of file paths to checksums of what was installed

### Step 1b: Legacy Layout Migration

If legacy layout is detected:

1. Explain migration clearly and ask for confirmation before any structural changes.
2. Require backup confirmation before changing layout:
   - Ask user to confirm they have backed up `.claude/` and task directories, or create `.dotcortex/backups/pre-migration-<timestamp>.tar.gz`.
   - If user declines backup, abort migration.
3. Create canonical directories:
   - `.dotcortex/{commands,skills,knowledge,memory}`
   - `.dotcortex/tasks`
4. Move managed content from `.claude/` to `.dotcortex/`.
5. Preserve `.claude/settings.local.json` exactly as-is.
6. Preserve unmanaged `.claude/` files (for example `.claude/hooks/`, `.claude/plans/`).
7. Detect current task path from legacy config (`tasks_dir`) and on-disk candidates (`.tasks`, `tasks`, legacy `claude_tasks`, `.claude/tasks`), then ask whether to move, copy, or skip migration into `.dotcortex/tasks`.
8. Create `.tasks -> .dotcortex/tasks` (or fallback copy view if symlinks unavailable).
9. Write `.dotcortex/config.json` and mark layout as migrated.
10. Rebuild tool views from `.dotcortex` (Step 9).

Migration must be idempotent and safe to re-run.

### Step 2: Clone Latest

```bash
# Clone to temp directory, shallow, latest only
TEMP_DIR=$(mktemp -d)
git clone --depth 1 "$SOURCE_REPO" "$TEMP_DIR/dotcortex"

# Get the latest tag
cd "$TEMP_DIR/dotcortex"
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "untagged")
```

If `LATEST_TAG` equals the installed version, report "Already up to date" and clean up.

### Step 3: Compare Each Managed File

For each file in `managed_files`:

1. **Render the new upstream version:**
   - Read the corresponding file from `$TEMP_DIR/dotcortex/`
   - Replace all instances of `PREFIX` with `config.prefix`
   - Replace all instances of `TASKS_DIR` with `.dotcortex/tasks`

2. **Hash the new rendered version** (SHA-256)

3. **Determine what changed:**

```
installed_hash = managed_files[path]        # what we installed last time
current_hash   = sha256(user's current file) # what's on disk now
new_hash       = sha256(new rendered file)    # what upstream looks like now
```

4. **Decide action:**

| Upstream changed? | User modified? | Action |
|---|---|---|
| No (`new_hash == installed_hash`) | — | Skip — nothing new |
| Yes | No (`current_hash == installed_hash`) | **Auto-update** — user hasn't touched it |
| Yes | Yes (`current_hash != installed_hash`) | **Conflict** — ask user |
| — | — (file missing) | Ask: reinstall or skip? |

### Step 4: Check for New Files

Compare the file list in the new dotcortex against `managed_files`. Any file in the new version that isn't in `managed_files` is a new addition.

For each new file:
- Show the file name and a one-line description
- Ask: "Install / Skip"
- If installing, render with prefix/tasks_dir and write it

### Step 5: Handle Conflicts

For each conflict (both upstream and user changed):

Present to the user:
```
⚠ Conflict: .dotcortex/skills/pm-agent/SKILL.md

Upstream changes (v1.0.0 → v1.2.0):
[Show a summary of what changed in the upstream version — new sections added,
 sections modified, sections removed. Read both versions and describe the diff
 in plain English, don't dump raw diffs.]

Your local changes:
[Summarize what the user added/modified compared to the original installed version.]

Options:
1. Keep mine — skip this update
2. Take upstream — overwrite with new version (your changes will be lost)
3. Show full diff — display both versions side by side for manual review
```

Use AskUserQuestion for each conflict.

If user picks "Show full diff", display both versions clearly labeled, then ask again: Keep mine / Take upstream.

### Step 6: Apply Updates

For each file being updated (auto-updates + user-approved overwrites):
1. Write the new rendered version to disk
2. Update the checksum in `managed_files`

### Step 7: Update Config

Update `.dotcortex/config.json`:
- Set `version` to the new tag
- Set `updated_at` to today's date
- Update `managed_files` with new checksums for all updated files
- Add entries for any newly installed files

### Step 8: Clean Up and Report

```bash
rm -rf "$TEMP_DIR"
```

Print summary:
```
dotcortex updated: v1.0.0 → v1.2.0

Auto-updated (no conflicts):
  ✓ .dotcortex/commands/next.md

Conflicts resolved:
  ✓ .dotcortex/skills/pm-agent/SKILL.md — kept yours
  ✓ .dotcortex/commands/standup.md — took upstream

New files installed:
  + .dotcortex/commands/retrospective.md

Skipped (no changes):
  - 8 files unchanged

Skipped (user declined):
  - .dotcortex/commands/new-command.md
```

## File Mapping

The update command needs to know which dotcortex source file maps to which installed file. The mapping follows this pattern:

| Localmem source | Installed at |
|---|---|
| `commands/*.md` | `.dotcortex/commands/*.md` |
| `skills/*/SKILL.md` | `.dotcortex/skills/*/SKILL.md` |
| `templates/*.md` | `.dotcortex/tasks/templates/*.md` |

### Step 9: Sync Multi-Tool Files

Always rebuild tool views from canonical `.dotcortex` content after updates.

1. Rebuild `.claude/` view from canonical sources:
   - `.dotcortex/org/*` (org-global, if connected)
   - `.dotcortex/org/projects/<project_key>/*` (org project overlay, if connected)
   - `.dotcortex/*` (local canonical)
   - Preserve `.claude/settings.local.json` as real file
   - Rebuild managed directories: `commands/`, `skills/`, `knowledge/`, `memory/`
   - Use collision order: org-global first, org-project second, local third (local wins)
2. Ensure `.tasks` points to `.dotcortex/tasks`
3. Rebuild other selected tools from `.dotcortex/skills`

**For each tool in `config.tools`:**

| Tool | Action |
|------|--------|
| `codex` | Regenerate `AGENTS.md` from `CLAUDE.md`. Rebuild `.agents/skills/` symlinks — remove stale ones, create new ones for any added skills. |
| `gemini` | Regenerate `GEMINI.md` from `CLAUDE.md`. Rebuild `.gemini/skills/` symlinks — same approach. |
| `cursor` | Regenerate `AGENTS.md` if not already done for Codex. Rebuild `.cursor/rules/*.mdc` files from current `.dotcortex/skills/*/SKILL.md` — delete `.mdc` files for removed skills, create new ones for added skills. |

**Symlink rebuild process:**
```bash
# Remove all existing symlinks in target skills dir (don't touch non-symlink files)
find .agents/skills -type l -delete 2>/dev/null

# Recreate symlinks for each current skill
for skill_dir in .dotcortex/skills/*/; do
  skill_name=$(basename "$skill_dir")
  ln -s "../../.dotcortex/skills/$skill_name" ".agents/skills/$skill_name"
done
```

Report any tool-specific files updated in the Step 8 summary.

## Edge Cases

- **User deleted a managed file:** Ask "This file was removed. Reinstall from upstream? / Skip"
- **dotcortex repo unreachable:** Report error, suggest checking network or repo URL
- **No git tags on upstream:** Use commit hash as version identifier instead
- **Config file corrupted:** Offer to re-run `/cortex-init` in repair mode
- **Tool added/removed since init:** If `config.tools` changed, run the appropriate setup/cleanup from Phase 4.8 of cortex-init
- **Symlink-incompatible environment:** use configured fallback mode (`symlinks: false`) and warn that view copies can drift

Arguments: $ARGUMENTS
