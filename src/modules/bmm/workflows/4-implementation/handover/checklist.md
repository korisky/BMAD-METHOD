---
title: 'Handover Checklist'
validation-target: 'Session end state'
validation-criticality: 'HIGH'
required-inputs:
  - 'Current git status'
  - 'Beads claim status'
  - 'Branch sync status'
optional-inputs:
  - 'Test results'
  - 'CI status'
---

# Handover Checklist

**Verify all items before ending session:**

## Beads Coordination

- [ ] **Claims Released:** All story claims released (`bd-release`)
- [ ] **No Active HALTs:** No unresolved HALT conditions (`bd list --priority 0`)

## Git State

- [ ] **No Uncommitted Changes:** `git status` shows clean working tree (or changes intentionally left)
- [ ] **Commits Pushed:** All commits pushed to remote (`git push`)
- [ ] **Branches Synced:** `bd-land` completed successfully

## Branch Alignment

- [ ] **beads-sync Merged:** `beads-sync` changes merged into `main`
- [ ] **main Merged:** `main` changes merged into working branch
- [ ] **Remote Updated:** Remote branches reflect local state

## Verification

- [ ] **Sync Status Clean:** `bd sync --status` shows no issues
- [ ] **No Divergence:** `git log --oneline --graph --all -5` shows aligned branches

## Next Session Prep

- [ ] **Ready Work Identified:** `bd-status` or `bd-next` shows available work
- [ ] **Blockers Documented:** Any blockers recorded in Beads (`bd-blocker`)

---

## Handover Summary

```
Handover: {{PASS/FAIL}}

Claims Released: {{yes/no}}
Changes Committed: {{yes/no}}
Branches Synced: {{yes/no}}
Remote Updated: {{yes/no}}

Next Ready Work:
{{bd-next output}}
```

**If FAIL:** Address failures before ending session or document reason for incomplete handover.

**If PASS:** Session can safely end. All work is synced and ready for next session.
