# Handoff: Existing Projects Migration

**For Future Agents: This document describes work needed to migrate EXISTING projects from global config to project-local.**

---

## Current State (As of v3.0)

**Fresh installations (NEW projects):**
- ✅ Install to `.beads/lib/bmad-aliases.sh` (project-local)
- ✅ NO global config created at `~/.bmad/`
- ✅ NO shell profile modification
- ✅ Simple, clean, isolated

**Existing projects (BEFORE v3.0):**
- ❌ Using global config at `~/.bmad/beads-aliases.sh`
- ❌ Shell profiles modified (auto-sourcing from `~/.bmad/`)
- ❌ Projects not isolated
- ❌ Multiple versions conflict

---

## Target State

All existing projects should migrate to:
- ✅ Project-local config (`.beads/lib/bmad-aliases.sh`)
- ✅ NO global config pollution
- ✅ NO shell profile modifications
- ✅ Each project isolated with its own version

---

## Migration Approach (Not Implemented Yet)

### Option 1: Migration Script (Recommended)

Create `migrate-to-local.sh` that:
1. Detects if project uses global config
2. Copies aliases to `.beads/lib/bmad-aliases.sh`
3. Updates all hooks to source project-local
4. Creates `.beads/.bmad-version` file
5. Optionally cleans up `~/.bmad/` if no other projects use it
6. Optionally removes shell profile modifications

**Benefits:**
- User-controlled migration
- Safe, reversible
- Clear verification steps

### Option 2: Installer Auto-Detection

Modify `install.sh` to:
1. Detect existing global config usage
2. Offer migration during re-installation
3. Handle both fresh installs AND migrations

**Benefits:**
- Single tool for all scenarios
- No separate migration script needed

**Risks:**
- More complex installer logic
- Harder to test

---

## Testing Requirements

Migration testing MUST verify:
- [ ] Existing projects continue working during migration
- [ ] No data loss (commit history, beads state)
- [ ] Hooks work after migration
- [ ] Multi-project scenarios (some migrated, some not)
- [ ] Cleanup is safe (doesn't break unmigrated projects)
- [ ] Shell profiles cleaned up correctly

**Test scenarios:**
1. Single project migration
2. Multiple projects (migrate one at a time)
3. Multiple projects (all at once)
4. Rollback if migration fails
5. Projects using Husky vs `.git/hooks`

---

## What NOT to Do

**DO NOT:**
- ❌ Force migration without user consent
- ❌ Delete global config while other projects might use it
- ❌ Modify shell profiles without backing them up
- ❌ Assume all projects are at the same version
- ❌ Break existing projects in the name of cleanup

**REMEMBER:**
- Existing projects are PRODUCTION - users depend on them
- Migration must be opt-in and reversible
- Clear communication about what changes and why
- Provide verification steps at each stage

---

## Implementation Plan (Future Work)

### Phase 1: Detection
- [ ] Create utility to detect config location
- [ ] Show warning in existing projects using global config
- [ ] Document migration path

### Phase 2: Migration Script
- [ ] Write `migrate-to-local.sh`
- [ ] Add dry-run mode
- [ ] Add verification checks
- [ ] Test in multiple scenarios

### Phase 3: Cleanup
- [ ] Detect if `~/.bmad/` is safe to remove
- [ ] Offer shell profile cleanup
- [ ] Provide rollback mechanism

### Phase 4: Documentation
- [ ] Migration guide for users
- [ ] Troubleshooting steps
- [ ] FAQ for common issues

---

## Success Criteria

Migration is successful when:
- [ ] Existing project works with project-local config
- [ ] All hooks source correct path
- [ ] No global config pollution
- [ ] `bd_health` shows project-local config
- [ ] User can verify migration succeeded
- [ ] Rollback works if needed

---

## Context for Future Agents

**Why this matters:**
- Fresh installations (v3.0+) never create global config
- Existing projects (pre-v3.0) still use global config
- Gap: No migration path for existing projects yet

**User impact:**
- Users with existing projects can't benefit from v3.0 improvements
- Multiple versions cause conflicts
- Global config pollutes user environment

**Priority:**
- LOW for users who only have one project
- MEDIUM for users with multiple projects
- HIGH for teams sharing projects (version conflicts)

**Complexity:**
- MEDIUM - clear requirements, known paths, testable
- Main risk: shell profile cleanup (many variations)
- Safest approach: opt-in, reversible, well-tested

---

## Files to Reference

When implementing migration:
- `install.sh` - Fresh installation (project-local only)
- `beads-aliases.sh` - Function definitions
- `beads-reference.md` - Workflow documentation
- This file - Migration requirements

---

## Questions to Resolve

Before implementing, clarify:
1. Should migration be automatic or manual?
2. How to handle shared `~/.bmad/` across multiple projects?
3. What if user has custom modifications to global config?
4. How to verify all hooks updated correctly?
5. Should we support mixed mode (some projects local, some global)?

---

**Last Updated:** 2026-02-01 (v3.0 fresh install implementation)
**Status:** Planning only - NO implementation yet
**Next Step:** Create migration script when user requests it
