# Beads Integration Reference (v0.2.0)

## Overview

BMAD + Beads integration provides agent-first workflow coordination. Beads owns all work state (tasks, blockers, decisions, gates). BMAD provides methodology templates loaded on-demand.

## Architecture

```
Target Project:
├── .bmad/           # Agent methodology (JIT-loaded)
│   ├── SKILL.md     # Bootstrap protocol (<300 tokens)
│   ├── personas/    # Role-specific guidance (<200 tokens each)
│   ├── templates/   # Document templates (PRD, story, ADR, etc.)
│   └── methodology/ # Phases, scale levels, triage, quality gates
├── .beads/          # Beads state
│   ├── formulas/    # Molecule templates
│   ├── lib/         # BMAD aliases (git-sync functions)
│   └── AGENTS.md    # Agent-first protocol
├── BMAD_MANIFEST.md # Universal agent discovery
└── _bmad/           # Standard BMAD install (human workflows)
```

## Agent Session Lifecycle

### 1. Session Start
```bash
bd prime              # Full project context
bd ready --json       # Available work queue
```

### 2. Claim and Execute
```bash
bd update <id> --status in_progress --claim --json
# ... do work ...
bd create "title" -t task   # Discovered work
bd create "title" -t gate   # Phase transition
```

### 3. Session End (Landing the Plane)
```bash
bd close <id> --reason "summary" --json
bd sync                     # Sync beads state
```

## Molecule Formulas

Molecules create structured task hierarchies for L3-L4 scale work:

```bash
bd mol pour bmad-feature --args "title=Feature Name"
bd mol pour bmad-bugfix --args "title=Bug Description"
```

### bmad-feature Formula
Creates an epic with 4 phases: analysis → planning → solutioning → implementation.
Each phase has tasks and a gate that must close before proceeding.

### bmad-bugfix Formula
Creates an epic with 3 phases: triage → fix → verification.
Streamlined for faster turnaround on bug fixes.

## Quality Gates

Gates enforce phase transitions. Create with:
```bash
bd create "Gate: analysis-complete" -t gate
```

Close when criteria met:
```bash
bd close <gate-id> --reason "All criteria met"
```

See `.bmad/methodology/quality-gates.md` for gate criteria per phase.

## BMAD_MANIFEST.md

Universal agent discovery file at project root. Contains:
- Environment paths (.bmad/, .beads/)
- Agent instructions (bd prime → bd ready → claim → work → close → sync)
- IDE/CLI-specific notes

Agents should read this file first to understand the project structure.

## Git Sync Architecture

### Three-Level Progressive Sync

1. **Post-commit** (background, non-blocking)
   - Runs `bd_auto_sync` in background
   - Syncs beads-sync branch if diverged
   - Logs to `.beads/logs/sync.log`

2. **Pre-push** (interactive, configurable)
   - Runs `bd_auto_land`
   - Checks beads-sync divergence
   - Behavior depends on `beads.auto-sync` config:
     - `warning` (default): Prompts before syncing
     - `auto`: Syncs automatically
     - `block`: Refuses push until synced
     - `off`: Skips check entirely

3. **Manual** (bd_land)
   - Three-way sync: beads-sync → default branch → current branch
   - Run when automatic sync isn't sufficient

### Three-Way Sync Flow

```
beads-sync ──merge──→ main/default ──merge──→ current-branch
     ↑                     ↑                       ↑
  bd daemon            bd_land step 1          bd_land step 2
  auto-commits
```

### Agent Mode

Agents should set `BEADS_NO_DAEMON=1` to skip daemon-related checks.
The daemon is designed for human interactive use; agents sync explicitly.

## Configuration

### Auto-Sync Mode
```bash
# View current
git config beads.auto-sync

# Set mode
git config beads.auto-sync <mode>
# Modes: warning (default), auto, block, off
```

### Workflow Mode
```bash
# View current
git config beads.workflow-mode

# Set mode
git config beads.workflow-mode <mode>
# Modes: mixed (default), agent, human, auto
```

## Troubleshooting

### Health Check
```bash
source .beads/lib/bmad-aliases.sh
bd_health
```

Reports on: daemon status, branch sync, in-progress tasks, HALTs, .bmad/ presence, configuration.

### Auto-Recovery
```bash
bd_fix
```

Attempts to fix: worktree branch issues, branch sync via bd_land.

### Common Issues

**"beads-sync is N commits ahead"**
- Run `bd_land` to sync branches
- Or set `git config beads.auto-sync auto` for automatic handling

**"Daemon using --auto-push"**
- Stop daemon: `bd daemon --stop`
- Restart without --auto-push: `bd daemon --start --interval 5s --auto-commit --auto-pull`

**"Not a git repository"**
- Run from project root
- Ensure `.git/` directory exists

**".bmad/SKILL.md missing"**
- Re-run installer: `bash <path>/install.sh`

### Sync Log
```bash
tail -f .beads/logs/sync.log
```

### Manual Recovery
If `bd_fix` doesn't resolve the issue:

1. Check branch state: `git branch -v`
2. Check worktree state: `git worktree list`
3. Force sync: `git checkout main && git merge beads-sync && git checkout -`
4. Re-initialize: `bd init`

## Scale Levels Quick Reference

| Level | Scope | Process | Beads |
|-------|-------|---------|-------|
| L1 | Single file fix | Direct fix | Single task |
| L2 | Small feature (1-3 files) | Light plan | Task group |
| L3 | Standard feature (4+ files) | Full 4-phase | `bmad-feature` molecule |
| L4 | Major initiative | Full + extra rigor | Molecule per epic |

Use `.bmad/methodology/triage.md` to determine scale level.
