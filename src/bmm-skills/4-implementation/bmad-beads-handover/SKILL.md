---
name: bmad-beads-handover
description: End-of-session Beads handover procedure that syncs branches, releases claims, and ensures push readiness. Use when the user says handover, session end, or wants to wrap up a Beads session.
---

# Beads Handover Workflow

**Goal:** Safely end a Beads session by releasing claims, syncing branches, and ensuring push readiness.

**Your Role:** Execute each step in order. Report results clearly. If any step fails, stop and advise the user on recovery.

---

## INITIALIZATION

Check if Beads is enabled: look for `.beads/` directory and `bd` CLI availability.
If Beads is not enabled, inform the user and end the workflow.

Source aliases if available: `source .beads/lib/bmad-aliases.sh`

---

## EXECUTION

### Step 1: Release Claims

Run: `bd list --type task --status in_progress`

If claims exist:
- Show them to the user
- Run `bd_release <id>` for each claim
- Confirm all released

If no claims: report clean and continue.

### Step 2: Commit Remaining Changes

Run: `git status --porcelain`

If uncommitted changes exist:
- Show the changes to the user
- Ask: commit now or leave for next session?
- If committing: stage and commit with an appropriate message

If clean: continue.

### Step 3: Sync Branches

Run: `bd_land`

This performs three-way sync: beads-sync → main → current branch.

If successful: report synced.
If failed: report the error and suggest `bd_fix` for recovery.

### Step 4: Verify Push Readiness

Run: `bd_preflight`

Report the checklist results:
- Working tree clean
- Branches synced
- No open claims

### Step 5: Push and Report

If preflight passed:
- Run `git push`
- Report success

If preflight failed:
- Show which checks failed
- Advise on fixes

Finally, show next ready work: `bd ready --pretty --limit 3`

Report: "Handover complete. Next session, start with `bd_session_start`."

## Handover Checklist

- [ ] All claims released (`bd list --type task --status in_progress` shows none)
- [ ] No uncommitted changes (`git status` clean)
- [ ] Branches synced (`bd_land` succeeded)
- [ ] Preflight passed (`bd_preflight` all green)
- [ ] Changes pushed (`git push` succeeded)
