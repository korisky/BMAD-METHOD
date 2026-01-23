---
title: "BMAD + Beads Integration Review (2026-01-22)"
description: "Comprehensive review of current integration status, gaps, and recommendations"
---

# BMAD + Beads Integration Review

**Review Date**: 2026-01-22  
**Reviewer**: Crush AI Assistant  
**Integration Version**: v5 (Efficient Integration Pattern)

## Executive Summary

The BMAD + Beads integration is **functional but lacks robustness for production team use**. The integration correctly separates concerns (BMAD handles formal workflows, Beads handles runtime coordination) but contains critical gaps that could cause branch divergence in collaborative environments. Most documentation exists but implementation lacks enforcement mechanisms.

## Current State Assessment

### ✅ What Works Correctly

1. **Architecture Separation**: Clear split between BMAD (formal outputs) and Beads (runtime coordination)
2. **Installation Integration**: BMAD installer has optional Beads integration with feature flags
3. **Agent Instructions**: Injections add Beads guidance to all agent markdown files
4. **Documentation**: Comprehensive `beads-git-workflow.md` and handover workflow exist
5. **Shell Aliases**: Useful `bd-*` commands for common operations

### ⚠️ Critical Gaps Identified

#### 1. **Git Workflow Implementation Gap**
- **Documented**: Three-way sync (`beads-sync → main → dev`) in `beads-git-workflow.md`
- **Implemented**: Pre-commit hook only runs `bd sync` (line 47-50 in `install.sh`)
- **Risk**: Branch divergence causing `.beads/issues.jsonl` conflicts across `beads-sync`, `main`, and `dev` branches

#### 2. **Missing Validation & Error Handling**
- **Installer**: No post-install validation of Beads setup (`runBeadsSetup()` lacks verification)
- **Recovery**: No built-in recovery procedures for daemon failures or branch conflicts
- **Detection**: Installer doesn't detect existing branch divergence

#### 3. **Clarity Gaps in Agent Instructions**
- **Injections**: Don't clearly differentiate "When to Use Beads vs BMAD"
- **Handover**: `[HO]` workflow integration exists but could be more explicit
- **Boundaries**: Risk of duplicate tracking (same data in both systems)

#### 4. **Missing Recovery Commands**
- **Documented**: Recovery procedure exists in `beads-git-workflow.md` (lines 140-202)
- **Missing**: No `bd-recovery` command in shell aliases
- **Missing**: No `bd-status-check` for daemon validation

## Technical Analysis

### Architecture Review

```
BMAD (Formal Workflows)          Beads (Runtime Coordination)
├── Workflow tracking            ├── Work claiming
├── Story status (yaml)          ├── Runtime decisions  
├── Phase progress               ├── Blockers & HALTs
├── ADRs (architecture.md)       ├── Cross-session memory
└── Code review findings         └── Action item tracking
```

**Correct Implementation**:
- Feature flag system (`beads-enabled`) controls injection
- Modular injection system with `requires` conditions
- Separate `beads` sub-module structure

### Code Review Findings

#### `/src/modules/bmm/sub-modules/beads/install.sh`
**Issue (lines 34-70)**: Pre-commit hook implements only `bd sync`, not three-way sync
```bash
# Current (inadequate):
bd sync || echo "⚠️  Beads sync failed"

# Required (per documentation):
git checkout main && git merge beads-sync --ff-only && git push
git checkout dev && git merge main && bd sync
```

#### `/tools/cli/installers/lib/core/installer.js`
**Issue**: No validation in `runBeadsSetup()` (lines 302-329)
- Missing `validateBeadsSetup()` function
- No post-install verification summary

#### `/src/modules/bmm/sub-modules/beads/injections.yaml`
**Issue**: Instructions lack context boundaries
- Should include "Use Beads for runtime coordination, BMAD for formal workflows"
- Missing "Don't duplicate data" warnings

### Handover Workflow Integration
**Status**: Partially integrated
- `handover/workflow.yaml` references beads workflow
- `handover/instructions.md` includes `bd-land` usage
- **Missing**: Automatic integration with `[HO]` command

## Risk Assessment

### High Risk
1. **Branch Divergence**: Without three-way sync, collaborative teams will experience `.beads/` conflicts
2. **Data Loss**: Force pushes to `beads-sync` could corrupt tracking data
3. **User Confusion**: Unclear when to use BMAD workflows vs Beads commands

### Medium Risk  
1. **Daemon Failures**: No recovery procedures for beads daemon issues
2. **Installation Failures**: Silent failures in Beads setup
3. **Agent Confusion**: Could track same data in both systems

### Low Risk
1. **Performance**: Additional git operations in hooks
2. **Learning Curve**: Additional commands to learn

## Recommendations (Prioritized)

### Phase 1: Critical Patches (Week 1)
**Goal**: Prevent branch divergence in collaborative environments

1. **Update Beads Install Script** (`install.sh:34-70`)
   - Implement three-way sync validation in pre-commit hook
   - Add branch validation to prevent worktree conflicts
   - Test command: `bash install.sh /tmp/test-project`

2. **Enhance Installer Validation** (`installer.js:302-327`)
   - Add `validateBeadsSetup()` function to check daemon status
   - Include post-install verification in summary
   - Test command: `npm run test:install`

3. **Improve Agent Instructions** (`injections.yaml:1-83`)
   - Add "When to Use Beads vs BMAD" section to each injection
   - Clarify handover workflow (`[HO]`) integration
   - Test command: `npm run test:schemas`

### Phase 2: User Experience (Week 2)
**Goal**: Improve clarity and recovery procedures

4. **Integrate with Handover Workflow** (`handover/workflow.yaml`)
   - Add beads sync steps to handover procedure
   - Create unified "land the plane" documentation
   - Test command: `*handover` workflow command

5. **Add Recovery Commands** (`beads-aliases.sh`)
   - Implement `bd-recovery` for branch divergence
   - Add `bd-status-check` for daemon validation
   - Test command: `source ~/.bmad/beads-aliases.sh && bd-recovery`

### Phase 3: Advanced Features (Week 3+)
**Goal**: Automated conflict detection and prevention

6. **Implement Automated Conflict Detection**
   - Git pre-push hook to detect branch divergence
   - Warning system for `.beads/` state mismatches
   - Auto-recovery for simple cases

7. **Add Integration Tests**
   - Test three-way sync scenarios
   - Simulate collaborative branch conflicts
   - Verify recovery procedures work

## Implementation Details

### Patch 1: Three-Way Sync Hook
```bash
# Proposed pre-commit hook addition:
if [ -d ".beads" ] && command -v bd &> /dev/null; then
    echo "Syncing beads..."
    bd sync || echo "⚠️  Beads sync failed"
    
    # Three-way sync validation
    CURRENT_BRANCH=$(git branch --show-current)
    if [ "$CURRENT_BRANCH" = "dev" ]; then
        echo "Checking branch sync status..."
        git fetch origin
        BEADS_AHEAD=$(git rev-list --count beads-sync..main)
        MAIN_AHEAD=$(git rev-list --count main..dev)
        if [ "$BEADS_AHEAD" -gt 0 ] || [ "$MAIN_AHEAD" -gt 0 ]; then
            echo "⚠️  Warning: Branches out of sync. Run 'bd-land' before push."
        fi
    fi
fi
```

### Patch 2: Installer Validation
```javascript
// Proposed validateBeadsSetup() function
async validateBeadsSetup(projectDir) {
  try {
    // Check beads daemon status
    const { execSync } = require('node:child_process');
    execSync('bd sync --status', { stdio: 'pipe' });
    
    // Check branch alignment
    const git = require('simple-git')(projectDir);
    const branches = await git.branch();
    
    // Return validation results
    return {
      daemonRunning: true,
      branchesAligned: this.checkBranchAlignment(branches),
      beadsInitialized: await fs.pathExists(path.join(projectDir, '.beads'))
    };
  } catch (error) {
    return { daemonRunning: false, error: error.message };
  }
}
```

## Testing Strategy

### Unit Tests
- `install.sh` hook functionality
- `bd-land` three-way sync correctness
- Injection system idempotency

### Integration Tests
1. **Fresh Installation**: BMAD + Beads from scratch
2. **Branch Divergence**: Simulate and recover from conflict
3. **Collaborative Work**: Multiple "agents" working simultaneously

### Manual Verification Checklist
- [ ] `npx bmad-method install` with Beads enabled completes successfully
- [ ] `bd-land` syncs `beads-sync → main → dev` correctly
- [ ] Pre-commit hook warns about unsynced branches
- [ ] Handover workflow integrates beads sync
- [ ] Recovery commands work for common failure scenarios

## Conclusion

The BMAD + Beads integration is **architecturally sound but operationally fragile**. The critical issue is the git workflow gap—without enforced three-way sync, collaborative teams will experience branch conflicts. Phase 1 patches should be implemented immediately to prevent data loss and user frustration.

**Recommendation**: Implement Phase 1 patches before promoting Beads integration for team use. The integration has strong potential but needs the robustness improvements outlined above.

---

**Files Requiring Changes**:
1. `/src/modules/bmm/sub-modules/beads/install.sh`
2. `/tools/cli/installers/lib/core/installer.js`  
3. `/src/modules/bmm/sub-modules/beads/injections.yaml`
4. `/src/modules/bmm/workflows/4-implementation/handover/instructions.md`
5. `/src/modules/bmm/sub-modules/beads/beads-aliases.sh`

**Review Complete**: 2026-01-22