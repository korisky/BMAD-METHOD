# Fork Strategy: BMAD-METHOD Beads Integration

## Branch Structure

- **upstream-sync/<date-or-tag>**: Curated upstream merge branches
  - Dedicated branches for upstream merges (created in git worktrees)
  - Conflicts resolved with deny-by-default policy
  - Validated before merging to main

- **main**: Curated baseline
  - Receives only curated commits from upstream-sync branches
  - No direct upstream merges
  - No Beads-specific modifications

- **ver_X.X.X** (dev branches): Beads integration work
  - Contains Beads sub-module integration
  - Merges from curated `main`
  - Far fewer conflicts due to curation in sync branches

## Workflow

### Updating from Upstream (Curated Sync Branch Approach)

**Step 1: Create sync branch in worktree**
```bash
git worktree add .worktrees/upstream-sync-$(date +%Y-%m-%d) -b upstream-sync/$(date +%Y-%m-%d) main
cd .worktrees/upstream-sync-$(date +%Y-%m-%d)
```

**Step 2: Merge upstream with deny-by-default policy**
```bash
# Add upstream remote if not already added
git remote add upstream https://github.com/bmad-code-org/BMAD-METHOD.git || true
git fetch upstream

# Merge from upstream (use specific tag for releases)
git merge upstream/main  # Or: git merge v6.0.0-Beta.5

# Resolve conflicts following curation rules (see below)
# KEEP: core framework, workflows, agents, tools, tests, docs
# DISCARD: .claude/skills, .augment, .coderabbit.yaml, release workflows
```

**Step 3: Validate sync branch**
```bash
npm test  # Must pass
npx . install  # Test installer in clean project
git log --oneline main..HEAD  # Review changes
```

**Step 4: Merge to main**
```bash
git checkout main
git merge upstream-sync/$(date +%Y-%m-%d)
git tag -a sync-$(date +%Y-%m-%d) -m "Curated upstream sync"
git push origin main --tags
```

**Step 5: Merge main to dev branch**
```bash
git checkout ver_X.X.X  # Current dev branch
git merge main  # Far fewer conflicts

# Resolve Beads-specific conflicts only
git checkout --ours src/bmm-skills/sub-modules/beads/
git checkout --ours CLAUDE.md
git checkout --ours package.json

npm install  # Regenerate lockfile if needed
npm test
git commit
```

**Step 6: Cleanup worktree**
```bash
git worktree remove .worktrees/upstream-sync-$(date +%Y-%m-%d)
```

## Curation Policy

### ALWAYS KEEP (Core Framework)
- `src/bmm-skills/` - BMM skills (phases 1-4)
- `src/core-skills/` - Core skills
- `tools/installer/` - **CRITICAL** installer code (restructured in v6.2.2)
- `.claude-plugin/` - Plugin marketplace metadata
- `tools/validate-*.js` - Validators
- `test/` - Tests and fixtures
- `docs/` - Framework documentation
- Root: `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md`

### ALWAYS DISCARD (Upstream Operational)
- `.claude/skills/` - Release automation skills (untracked)
- `.augment/` - Code review guidelines (untracked)
- `.coderabbit.yaml` - CodeRabbit config (keep untracked/local-only)
- `.github/PULL_REQUEST_TEMPLATE.md` - PR template
- `.github/workflows/coderabbit-review.yaml` - Review workflow
- `.github/workflows/manual-release.yaml` - Release automation
- `website/` - Documentation site cosmetic changes (optional)

### CASE-BY-CASE (Evaluate Impact)
- `.github/workflows/` - CI workflows (keep quality checks, discard release automation)
- `package.json` - Dependencies (merge carefully, preserve fork identity)
- `eslint.config.mjs` - Linting rules (evaluate compatibility)

## Conflict Resolution Strategy

When resolving conflicts in the sync branch:

```bash
# For files in KEEP categories
git checkout --theirs path/to/file  # Accept upstream

# For files in DISCARD categories
git checkout --ours path/to/file    # Keep current fork version

# For complex conflicts
git mergetool  # Manual resolution
```

## Identity Management

**Fork-specific fields in package.json:**
- `name`: `bmad-method-beads-experimental`
- `version`: `<upstream>-beads.X.Y.Z` (e.g. `6.2.2-beads.0.3.0`)
- `bin`: `bmad-beads`, `bmad-beads-method`

**After any package.json merge:**
```bash
rm package-lock.json node_modules -rf
npm install  # Regenerate with fork identity
```

## Version Tracking

| Field | Value |
|-------|-------|
| **Upstream base** | BMAD-METHOD v6.2.2 |
| **Fork version** | `6.2.2-beads.0.3.0` |
| **Last upstream sync** | 2026-03-28 |
| **Dev branch** | `ver_0.3.0` |
| **Beads sub-module** | see `src/bmm-skills/sub-modules/beads/config.yaml` |

**Version format:** `<upstream>-beads.<major>.<minor>.<patch>`

Update this table after each upstream sync or Beads version bump.

## Testing Requirement

After any upstream sync, **MUST** test installation in a clean target project:

```bash
cd /tmp/test-bmad-project && npm init -y
npx /path/to/repo install
# Verify: agents, workflows, Beads hooks all work correctly
```

## Rationale

**Why curated sync branches?**
- Prevents 220-file merge pollution in dev branches
- Allows thorough review before accepting upstream changes
- Isolates upstream merge work in git worktrees
- Enables testing before affecting main/dev branches

**Why deny-by-default policy?**
- Upstream includes operational files (skills, review configs) not relevant to fork
- Accepting everything creates noise and confusion
- Explicit KEEP list ensures critical improvements aren't missed

**Why main as curated baseline?**
- Dev branches merge from main, not directly from upstream
- Main serves as pre-vetted integration point
- Reduces conflicts and testing burden on dev branches

## Critical Files to Watch

**High-impact files from upstream:**
- `tools/installer/core/installer.js` - Main installer orchestrator
- `tools/installer/modules/official-modules.js` - Core + BMM module handling
- `tools/installer/core/install-paths.js` - Path resolution
- `tools/validate-skills.js` - Skill validation (affects all skills)

**Fork-specific files to protect:**
- `src/bmm-skills/sub-modules/beads/` - Beads integration
- `src/bmm-skills/4-implementation/bmad-beads-handover/` - Handover skill
- `CLAUDE.md` - Fork-specific instructions
- `package.json` - Fork identity
- `.gitignore` - Untracked file rules

## Troubleshooting

### Issue: Merge conflicts in package-lock.json
**Solution:** Regenerate from package.json
```bash
git checkout --ours package.json
rm package-lock.json node_modules -rf
npm install
git add package-lock.json
```

### Issue: Tests failing in sync branch
**Solution:** Investigate before merging to main
```bash
npm test -- --verbose
# Fix issues in sync branch before merging
```

### Issue: Beads integration breaks after sync
**Solution:** Check for workflow file path changes
```bash
git diff main..HEAD -- src/bmm-skills/
# Update Beads coordination if skill paths changed
```

### Issue: Too many conflicts in dev branch merge
**Solution:** Review curation - may have accepted too much from upstream
```bash
# Check what was accepted
git diff sync-YYYY-MM-DD^..sync-YYYY-MM-DD -- .claude .augment .github
# If operational files slipped through, remove them before merging to dev
```
