# Integration Design Decisions (v3)

> Why we split BMAD and Beads this way

---

## Critical Insight

BMAD already has comprehensive tracking:
- **Phase progress**: `bmm-workflow-status.yaml`
- **Architectural decisions**: ADRs in `architecture.md`
- **Story status**: `sprint-status.yaml`
- **Task progress**: Story file checkboxes

**Beads should NOT duplicate any of this.**

---

## What Beads Actually Adds

Beads captures what happens OUTSIDE formal BMAD workflows:

| Concern | Why BMAD Can't | Beads Solution |
|---------|---------------|----------------|
| Runtime decisions | Workflows only capture planned decisions | `--type decision` for ad-hoc choices |
| External blockers | No workflow for "waiting on external API" | `--type blocker` |
| Cross-story deps | sprint-status.yaml is flat (no relationships) | `bd dep add` |
| Context after /clear | BMAD docs exist but agent loses pointer | DOC: notes point back |

---

## Key Decisions Made

### Decision 1: NO Phase Tracking in Beads

**Old plan**: Create "Phase: PRD Complete" epics in Beads

**Problem**: `bmm-workflow-status.yaml` already tracks this:
```yaml
workflow_status:
  prd: "docs/prd.md"  # Done
  create-architecture: required  # Not done
```

**New plan**: Don't track phases in Beads. Let BMAD handle it.

### Decision 2: NO ADR Duplication

**Old plan**: Create Beads decision for each ADR

**Problem**: ADRs already captured in `architecture.md` during step-04-decisions.md

**New plan**: Only create Beads decisions for RUNTIME decisions (made outside workflows)

### Decision 3: "Runtime Decision" Definition

A runtime decision is a choice made AFTER a BMAD workflow has completed its output:

| Runtime? | Example |
|----------|---------|
| No | Architect chooses database in architecture workflow |
| **Yes** | DEV discovers mid-implementation: "need different approach" |
| No | PM defines requirements in PRD workflow |
| **Yes** | PM says during sprint: "actually, drop that feature" |

### Decision 4: Blockers Are Beads-Only

BMAD has no construct for external impediments. Beads fills this gap:
- "Waiting on credentials"
- "Need stakeholder approval"
- "Dependent service is down"

### Decision 5: Cross-Story Dependencies Are Beads-Only

`sprint-status.yaml` is a flat list - no relationship tracking. Beads adds:
```bash
bd dep add <story-3> <story-2>  # Story 3 blocked until Story 2 done
```

---

## BMAD Installation Integration

### How Beads Should Hook In

Based on analysis of BMAD's module system, Beads can integrate as:

**Option A: Sub-module of BMM** (Recommended for quick start)
```
src/modules/bmm/sub-modules/beads/
├── config.yaml
├── injections.yaml     # Inject critical_actions into agents
└── readme.md
```

**Option B: Standalone Module** (For full integration)
```
src/modules/beads/
├── module.yaml
├── _module-installer/
│   └── installer.js    # Init Beads CLI
└── sub-modules/
    └── claude-code/
        └── injections.yaml
```

### Installation Flow

1. User runs `npx bmad-method install`
2. Selects BMM module
3. Prompted: "Enable Beads for runtime tracking?"
4. If yes:
   - Check/install `bd` CLI
   - Run `bd init` in project
   - Inject Beads critical_actions into agent files
   - Set up git hooks for `bd sync`

---

## The 1+1 > 2 Value

| Alone | Combined |
|-------|----------|
| BMAD: Great docs, but runtime changes get lost | Runtime changes captured in Beads |
| BMAD: No blocker tracking | Blockers visible and actionable |
| BMAD: Flat story list | Dependencies explicit in Beads |
| Beads: Good tracking, no doc generation | Rich docs from BMAD |

**The synergy**: BMAD generates formal artifacts. Beads captures the chaos that happens between formal steps.

---

## What We Avoided

| Complexity | Status |
|------------|--------|
| Story-level Beads issues | Removed - sprint-status.yaml handles this |
| Phase tracking in Beads | Removed - workflow-status.yaml handles this |
| ADR duplication | Removed - architecture.md handles this |
| Status sync scripts | Never needed - systems track different things |

---

## Migration Path

For projects already using BMAD:

1. Run `bd init` (if not done)
2. Start capturing runtime decisions and blockers
3. No need to backfill - BMAD artifacts are already the source of truth
4. Beads adds incremental value for runtime state
