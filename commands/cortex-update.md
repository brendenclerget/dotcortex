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
- `.dotcortex/install-info.json` with migration markers

If `.dotcortex/config.json` **does** exist, it is the sole authority — ignore any stale legacy files (e.g., an old `.claude/.localmem.json`) entirely; do not let them route you into migration.

If config is absent and any legacy marker exists, detect a legacy install and ask the user to choose:
1. Run `install.sh --with-migrations ...` then re-run `/cortex-update`
2. Run `/cortex-init` in augment mode to rebuild canonical layout

If none exist, stop and tell the user to run `/cortex-init` first.

Extract:
- `source` — GitHub repo URL
- **Installed version** — read `dotcortex_version` from `.dotcortex/install-info.json` (the canonical version field; `.dotcortex/version` mirrors it; config.json does not store a version)
- `config.prefix` — ticket prefix (e.g., "APP")
- `config.tools` — enabled tool views (e.g., `["claude", "codex"]`)
- `config.context_repo` — team context connection, when present
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
9. Write `.dotcortex/config.json` and mark layout as migrated, then delete stale legacy marker files (`.claude/.dotcortex.json`, `.claude/.localmem.json`) so they can never shadow the canonical config.
10. Rebuild tool views from `.dotcortex` (Step 9).

Migration must be idempotent and safe to re-run.

### Step 2: Clone Latest

```bash
# Clone with tags and CHECK OUT the exact latest release tag.
# Never render from arbitrary branch HEAD.
TEMP_DIR=$(mktemp -d)
git clone "$SOURCE_REPO" "$TEMP_DIR/dotcortex"
cd "$TEMP_DIR/dotcortex"
LATEST_TAG=$(git tag --sort=-v:refname | head -1)
if [ -z "$LATEST_TAG" ]; then echo "No release tags upstream — aborting update."; fi
git checkout --quiet "$LATEST_TAG"
```

The installed version is `dotcortex_version` in `install-info.json` (the same value install.sh wrote — an exact tag, or `untagged-<sha>` for dev installs). "Already up to date" requires BOTH: `LATEST_TAG` equals it, AND every `managed_files[].base_version` equals it — a post-init installer re-run bumps install-info without re-rendering, so the payload can lag the recorded version. If only the payload lags, proceed with the update using the manifest's base_versions as merge bases.

### Step 3: Compare Each Managed File

Each `managed_files` entry records `{sha256, base_version, source}` — written by `bin/render.sh` at install time. `base_version` is the exact tag the file was rendered from, so the true installed base is always retrievable (`git checkout <base_version> -- <source>` in the temp clone) for a real three-way merge.

**Never mutate live state during comparison.** Copy `.dotcortex/config.json` to a temp path first; all candidate renders below use `--config <temp copy>` so the live `managed_files` is untouched until Step 6 applies decisions.

For each file in `managed_files` (each entry is `{sha256, base_version, source}`, where `source` is the repository-relative path render.sh recorded):

1. **Render the NEW candidate:** `bin/render.sh` from the checked-out `$LATEST_TAG` into a temp dest, using the temp config.

2. **Reconstruct the BASE (the rendered bytes that produced `installed_hash`):** in the temp clone, `git checkout <base_version> -- <source>`, then render *that* with the temp config into a second temp dest. The base for merging is this **rendered** output — never the raw tokenized source.

3. **Determine what changed:**

```
installed_hash = managed_files[path].sha256   # what we installed last time
current_hash   = sha256(user's current file)  # what's on disk now
new_hash       = sha256(new rendered candidate)
base_file      = rendered base (step 2) — sha256(base_file) must equal installed_hash;
                 if it doesn't, warn and treat as conflict (manifest drift)
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

For each conflict (both upstream and user changed), **attempt a real three-way merge first**:

```bash
# current = user's file, base = rendered base from Step 3.2, new = rendered candidate
git merge-file -p <current> <base> <new> > <merged> && CLEAN=1 || CLEAN=0
```

- **Clean merge** (`CLEAN=1`): apply `<merged>`, report it as "merged (upstream + your changes)" in the summary. No prompt needed. **Manifest bookkeeping for merged files:** record `sha256 = hash of the NEW RENDERED CANDIDATE` (not of the merged file) with `base_version: $LATEST_TAG` — the merged content on disk then correctly reads as user-modified at the next update, and the rendered base at `$LATEST_TAG` reproduces the recorded hash. Recording the merged file's own hash instead would make the next update's rendered-base drift check fail unconditionally.
- **Merge conflicts**: fall through to the interactive prompt below.

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

For each file being updated:
1. Write the file to disk: the new rendered version (auto-updates and "take upstream"), or the merged output (clean three-way merges)
2. Update `managed_files`: **always** `{sha256: hash of the new rendered candidate, base_version: $LATEST_TAG, source}` — for every applied file including merged ones (see Step 5's bookkeeping rule); never the hash of merged content

### Step 7: Update Version + Config

One canonical version write path — the same fields install.sh writes, so the next update reads what this one wrote:
- `.dotcortex/install-info.json`: set `dotcortex_version` to `$LATEST_TAG`, set `previous_dotcortex_version`, `updated_at`, `updated_on`
- `.dotcortex/version`: write `$LATEST_TAG` (mirror)

Update `.dotcortex/config.json`:
- Set `updated_at` to today's date
- Update `managed_files`: new `{sha256, base_version: $LATEST_TAG, source}` entries for every applied file (config.json does **not** store a version field)

### Step 8: Report

(Cleanup happens at the END of Step 9 — the rebuild engine runs from the temp clone, so `$TEMP_DIR` must still exist.)

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

`managed_files[].source` (repository-relative, e.g. `base/pm/commands/ticket-new.md`) is the authoritative source mapping for every managed file — recorded by the renderer at install time. There is no static path table.

### Step 9: Rebuild Views

Layer resolution and tool views have exactly one engine — run it **from the checked-out temp clone** (the project itself may not ship `bin/`):

```bash
"$TEMP_DIR/dotcortex/bin/rebuild-views.sh" --root <project-root>
```

It resolves `layers/org` → `layers/team` (team wins, overrides reported) into the `.dotcortex/` resolved directories and points the `.claude/`/`.agents/` views at them. Do not re-describe or re-implement any of that here.

Afterwards:
1. Ensure `.tasks` points to `.dotcortex/tasks`
2. Tool-specific regeneration for each tool in `config.tools`: `codex` → regenerate `AGENTS.md` from `CLAUDE.md`; `gemini` → regenerate `GEMINI.md`; `cursor` → regenerate `.cursor/rules/*.mdc` from current skills

Report any tool-specific files updated in the Step 8 summary, then clean up:

```bash
rm -rf "$TEMP_DIR"
```

## Edge Cases

- **User deleted a managed file:** Ask "This file was removed. Reinstall from upstream? / Skip"
- **dotcortex repo unreachable:** Report error, suggest checking network or repo URL
- **No git tags on upstream:** Abort with "No release tags upstream" (per Step 2) — never update from untagged branch HEAD
- **Config file corrupted:** Offer to re-run `/cortex-init` in repair mode
- **Tool added/removed since init:** If `config.tools` changed, run the appropriate setup/cleanup from Phase 4.8 of cortex-init
- **Symlink-incompatible environment:** use configured fallback mode (`symlinks: false`) and warn that view copies can drift

Arguments: $ARGUMENTS
