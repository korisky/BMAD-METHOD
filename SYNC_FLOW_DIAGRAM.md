# BMAD + Beads Sync Automation Flow Diagram

## Three Levels of Automatic Sync

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         DEVELOPER WORKFLOW                                │
└──────────────────────────────────────────────────────────────────────────┘

                              git commit -m "..."
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ LEVEL 1: POST-COMMIT HOOK (Background Sync)                            │
├─────────────────────────────────────────────────────────────────────────┤
│ Trigger:  .git/hooks/post-commit                                       │
│ Action:   (bd_auto_sync &) 2>/dev/null                                 │
│ Behavior: Non-blocking background sync                                 │
│ Log:      .beads/logs/sync.log                                         │
│                                                                         │
│ Flow:                                                                   │
│   1. Check if beads-sync exists → Skip if not                          │
│   2. Check divergence (beads-sync ahead of main) → Skip if none        │
│   3. Run bd_land silently in background                                │
│   4. Log results to .beads/logs/sync.log                               │
│                                                                         │
│ Result: Branches stay synced after every commit                        │
└─────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
                              (work continues)
                                     │
                                     ▼
                                 git push
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ LEVEL 2: PRE-PUSH HOOK (Interactive Check)                             │
├─────────────────────────────────────────────────────────────────────────┤
│ Trigger:  .git/hooks/pre-push                                          │
│ Action:   bd_auto_land || exit 1                                       │
│ Config:   git config beads.auto-sync (warning|block|auto|off)          │
│                                                                         │
│ Flow by Mode:                                                           │
│                                                                         │
│   MODE: warning (default)                                              │
│   ├─ Check divergence                                                  │
│   ├─ If diverged: "Run bd_land? [y/N]"                                 │
│   │   ├─ User says Y → bd_land → push continues                        │
│   │   └─ User says N → exit 1 → push blocked                           │
│   └─ If synced: pass through                                           │
│                                                                         │
│   MODE: auto                                                            │
│   ├─ Check divergence                                                  │
│   ├─ If diverged: Auto-run bd_land → push continues                    │
│   └─ If synced: pass through                                           │
│                                                                         │
│   MODE: block                                                           │
│   ├─ Check divergence                                                  │
│   ├─ If diverged: "Push blocked. Run bd_land" → exit 1                 │
│   └─ If synced: pass through                                           │
│                                                                         │
│   MODE: off                                                             │
│   └─ Skip check entirely → pass through                                │
│                                                                         │
│ Result: Push only succeeds if branches synced (or mode=off)            │
└─────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
                           (push to remote succeeds)
                                     │
                                     ▼
                         (continue working or end session)
                                     │
                                     ▼
                          [HO] Handover Workflow
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ LEVEL 3: HANDOVER SYNC (Mandatory)                                     │
├─────────────────────────────────────────────────────────────────────────┤
│ Trigger:  Manual [HO] workflow Step 3                                  │
│ Action:   bd_land (always execute, not conditional)                    │
│ Purpose:  Guarantee session-end sync                                   │
│                                                                         │
│ Flow:                                                                   │
│   Step 1: bd_release <claim-id>  (release claims)                      │
│   Step 2: git commit              (commit changes)                     │
│   Step 3: bd_land                 (MANDATORY sync - always runs)       │
│   Step 4: bd_preflight            (verify ready)                       │
│   Step 5: git push                (push to remote)                     │
│                                                                         │
│ Result: Session ends with all branches guaranteed synced               │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Configuration Decision Tree

```
                        Which mode should I use?
                                 │
                                 ▼
                ┌────────────────┴────────────────┐
                │                                  │
         Learning workflow?              Experienced user?
         Want manual control?             Trust automation?
                │                                  │
                ▼                                  ▼
        ┌──────────────┐                  ┌──────────────┐
        │   WARNING    │                  │     AUTO     │
        │   (default)  │                  │  (seamless)  │
        └──────────────┘                  └──────────────┘
                │                                  │
         Asks: "Run bd_land?"              Auto-syncs silently
         Before push                       No prompts


                ┌────────────────┴────────────────┐
                │                                  │
        Team enforcement?                 Solo work?
        Strict discipline?                No daemon?
                │                                  │
                ▼                                  ▼
        ┌──────────────┐                  ┌──────────────┐
        │    BLOCK     │                  │     OFF      │
        │  (enforced)  │                  │  (disabled)  │
        └──────────────┘                  └──────────────┘
                │                                  │
         Blocks push until synced          Skips all checks
         No bypass allowed                 Manual sync only
```

---

## Sync Mechanism Detail

```
┌──────────────────────────────────────────────────────────────────────────┐
│                     bd_land: Three-Way Branch Sync                       │
└──────────────────────────────────────────────────────────────────────────┘

    Step 1: Detect branches
    ├─ Find default branch (main or master)
    ├─ Check if beads-sync exists
    └─ Remember current branch

                      ▼

    Step 2: Sync beads-sync → default branch
    ├─ git checkout main
    ├─ git merge beads-sync --no-ff -m "merge: sync beads tracking"
    ├─ git push origin main
    └─ Result: main now has latest beads data

                      ▼

    Step 3: Sync default → current branch (if different)
    ├─ git checkout <current-branch>
    ├─ git merge main --no-ff -m "merge: sync from main"
    ├─ git push origin <current-branch>
    └─ Result: current branch synced with main + beads data

                      ▼

    Step 4: Report success
    └─ "✅ All synced. Ready to continue working."


┌──────────────────────────────────────────────────────────────────────────┐
│                         Branch State After Sync                          │
└──────────────────────────────────────────────────────────────────────────┘

    beads-sync:  A──B──C──D──E──F
                              │
                              └──┐
                                 ▼
    main:        A──B──C──D──E──F  (synced)
                              │
                              └──┐
                                 ▼
    dev:         A──B──C──D──E──F  (synced)

    All branches have identical .beads/issues.jsonl
```

---

## Error Handling Flow

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    What If Something Goes Wrong?                         │
└──────────────────────────────────────────────────────────────────────────┘

    Problem Detected
         │
         ▼
    ┌──────────────────┐
    │   bd_health      │  ← Run diagnostic check
    └──────────────────┘
         │
         ├─ Daemon not running? → bd daemon start
         ├─ Worktree conflict? → bd_fix
         ├─ Branch diverged? → bd_land
         └─ Merge conflict? → Manual resolution
         │
         ▼
    ┌──────────────────┐
    │   bd_fix         │  ← Auto-fix attempt
    └──────────────────┘
         │
         ├─ Fix worktree branch
         ├─ Run bd_land
         └─ Verify with bd_preflight
         │
         ▼
    Problem Resolved ✅
         │
         OR
         ▼
    ┌──────────────────────────────────────────┐
    │ Manual Recovery                          │
    ├──────────────────────────────────────────┤
    │ See: docs/beads-reference.md             │
    │      "Troubleshooting" section           │
    └──────────────────────────────────────────┘
```

---

## Background Sync Details

```
┌──────────────────────────────────────────────────────────────────────────┐
│              bd_auto_sync: Background Sync Implementation                │
└──────────────────────────────────────────────────────────────────────────┘

    git commit -m "..."  →  Post-commit hook triggered
                                      │
                                      ▼
                            ┌──────────────────────┐
                            │  Fork to background  │
                            │  (bd_auto_sync &)    │
                            └──────────────────────┘
                                      │
                    ┌─────────────────┴─────────────────┐
                    │                                   │
                    ▼                                   ▼
            Main Process                        Background Process
            Continues                                   │
            (git commit                                 ▼
             completes                     Check if beads-sync exists
             immediately)                               │
                                                        ▼
                                            Check divergence (ahead count)
                                                        │
                                    ┌───────────────────┴───────────────┐
                                    │                                   │
                                    ▼                                   ▼
                            ahead > 0?                            ahead = 0?
                                    │                                   │
                                    ▼                                   ▼
                            Run bd_land                          Skip (no-op)
                            (in background)                            │
                                    │                                   │
                                    ▼                                   │
                            Log to .beads/logs/sync.log                 │
                                    │                                   │
                                    └───────────────────────────────────┘
                                                    │
                                                    ▼
                                            Background complete
                                            (parent process unaware)


    Developer Experience:
    ─────────────────────
    $ git commit -m "feat: add auth"
    [main abc123] feat: add auth
     2 files changed, 50 insertions(+)
    $ ← Prompt returns immediately, sync happens in background

    Check sync log:
    $ tail .beads/logs/sync.log
    === 2026-01-29 14:32:15 ===
    Syncing: beads-sync is 1 commits ahead
    [sync output...]
    Complete: 2026-01-29 14:32:18
```

---

**For complete reference, see `src/modules/bmm/sub-modules/beads/beads-reference.md`**
