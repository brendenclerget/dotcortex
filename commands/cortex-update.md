---
name: cortex-update
description: Check for and apply updates from the dotcortex repository while preserving user customizations
---

# cortex-update: Update Managed Files

Update dotcortex-managed commands, skills, and templates from the latest upstream release while preserving user customizations.

## Process

### Step 1: Read Config

Read `.claude/.dotcortex.json` from the project root. If it doesn't exist, stop and tell the user to run `/cortex-init` first.

Extract:
- `source` — GitHub repo URL
- `version` — currently installed version tag
- `config.prefix` — ticket prefix (e.g., "TCG")
- `config.tasks_dir` — task directory path (e.g., ".tasks")
- `managed_files` — map of file paths to checksums of what was installed

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
   - Replace all instances of `TASKS_DIR` with `config.tasks_dir`

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
⚠ Conflict: .claude/skills/pm-agent/SKILL.md

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

Update `.claude/.dotcortex.json`:
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
  ✓ .claude/commands/next.md

Conflicts resolved:
  ✓ .claude/skills/pm-agent/SKILL.md — kept yours
  ✓ .claude/commands/standup.md — took upstream

New files installed:
  + .claude/commands/retrospective.md

Skipped (no changes):
  - 8 files unchanged

Skipped (user declined):
  - .claude/commands/new-command.md
```

## File Mapping

The update command needs to know which dotcortex source file maps to which installed file. The mapping follows this pattern:

| Localmem source | Installed at |
|---|---|
| `commands/*.md` | `.claude/commands/*.md` |
| `skills/*/SKILL.md` | `.claude/skills/*/SKILL.md` |
| `templates/*.md` | `TASKS_DIR/templates/*.md` (path from config) |

## Edge Cases

- **User deleted a managed file:** Ask "This file was removed. Reinstall from upstream? / Skip"
- **dotcortex repo unreachable:** Report error, suggest checking network or repo URL
- **No git tags on upstream:** Use commit hash as version identifier instead
- **Config file corrupted:** Offer to re-run `/cortex-init` with augment mode

Arguments: $ARGUMENTS
