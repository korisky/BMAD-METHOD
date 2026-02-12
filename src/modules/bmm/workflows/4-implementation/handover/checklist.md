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

**Run `bd_preflight` to verify most items automatically.**

## Before Handover

- [ ] **Claims Released:** `bd_release <id>` for any claimed stories
- [ ] **Changes Committed:** `git status` shows clean tree

## Preflight Check

- [ ] **Run `bd_preflight`** → Should show all ✅

If ❌ appears:

- [ ] **Run `bd_land`** to sync branches
- [ ] **Run `bd_preflight`** again to verify

## Push

- [ ] **Run `git push`** when preflight shows ✅

## Optional: Next Session Prep

- [ ] **Ready Work Identified:** `bd_session_start` shows available work
- [ ] **Blockers Documented:** Any blockers recorded (`bd_blocker`)

---

## Handover Summary

```
bd_preflight: {{✅ Ready / ❌ Not Ready}}
git push: {{done / skipped}}

Next Ready Work:
{{bd_session_start output}}
```

**If not ready:** Run `bd_fix` or `bd_land` and try again.

**If ready:** Session can safely end.
