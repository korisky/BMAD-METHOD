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

**Run `bd-preflight` to verify most items automatically.**

## Before Handover

- [ ] **Claims Released:** `bd-release <id>` for any claimed stories
- [ ] **Changes Committed:** `git status` shows clean tree

## Preflight Check

- [ ] **Run `bd-preflight`** → Should show all ✅

If ❌ appears:
- [ ] **Run `bd-land`** to sync branches
- [ ] **Run `bd-preflight`** again to verify

## Push

- [ ] **Run `git push`** when preflight shows ✅

## Optional: Next Session Prep

- [ ] **Ready Work Identified:** `bd-status` shows available work
- [ ] **Blockers Documented:** Any blockers recorded (`bd-blocker`)

---

## Handover Summary

```
bd-preflight: {{✅ Ready / ❌ Not Ready}}
git push: {{done / skipped}}

Next Ready Work:
{{bd-status output}}
```

**If not ready:** Run `bd-fix` or `bd-land` and try again.

**If ready:** Session can safely end.
