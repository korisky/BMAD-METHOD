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
│   ├─ If diverged: Auto-run bd_land → push continues                    │
│   └─ If synced: pass through                                           │
│                                                                         │
│   MODE: block                                                           │
│   ├─ If diverged: "Push blocked. Run bd_land" → exit 1                 │
│   └─ If synced: pass through                                           │
│                                                                         │
│   MODE: off → Skip check entirely → pass through                       │
│                                                                         │
│ Result: Push only succeeds if branches synced (or mode=off)            │
└─────────────────────────────────────────────────────────────────────────┘
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

## Auto-Sync Mode Selection

| Mode | Use When | Behavior |
|------|----------|----------|
| `warning` (default) | Learning, want manual control | Asks before syncing |
| `auto` | Experienced, trust automation | Syncs silently |
| `block` | Team enforcement, strict discipline | Blocks push until synced |
| `off` | Solo work, no daemon | Skips all checks |

---

## Error Handling Flow

```
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
            (prompt returns                             ▼
             immediately)                   Check beads-sync divergence
                                                        │
                                    ┌───────────────────┴───────────────┐
                                    │                                   │
                                    ▼                                   ▼
                            ahead > 0?                            ahead = 0?
                                    │                                   │
                                    ▼                                   ▼
                            Run bd_land                          Skip (no-op)
                            Log to .beads/logs/sync.log
```

---

**For complete reference, see `src/bmm-skills/sub-modules/beads/beads-reference.md`**
