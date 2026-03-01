# Migrating Existing Projects to BMAD + Beads v0.2.0

## Overview

If your project already has BMAD installed (`_bmad/` directory) and/or Beads initialized (`.beads/` directory), this guide covers upgrading to the agent-first v0.2.0 integration.

## What's New in v0.2.0

- **`.bmad/` directory**: Agent methodology with SKILL.md, personas, templates, methodology docs
- **`BMAD_MANIFEST.md`**: Universal agent discovery file at project root
- **Molecule formulas**: `.beads/formulas/` with BMAD workflow templates
- **Agent-first protocol**: Native `bd` commands instead of `bd_*` wrappers
- **Quality gates**: Phase transitions tracked as Beads gate issues

## Migration Steps

### 1. Run the Installer

The installer is idempotent — safe to run on existing projects:

```bash
bash <path-to-bmad-repo>/src/bmm/sub-modules/beads/install.sh /path/to/your-project
```

This will:
- Create `.bmad/` with SKILL.md, personas, templates, methodology
- Generate `BMAD_MANIFEST.md` at project root
- Install molecule formulas to `.beads/formulas/`
- Update `.beads/lib/bmad-aliases.sh` to v0.2.0
- Update `.beads/AGENTS.md` managed block to agent-first protocol
- Preserve existing git hooks (extends, doesn't replace)

### 2. Update Git Hooks (if needed)

If you had v0.1.0 hooks:
- Pre-push hook is updated to respect `BEADS_NO_DAEMON=1` for agents
- Post-commit hook remains the same (background sync)
- Pre-commit hook unchanged

### 3. Update Workflow Mode

If migrating from human-centric to agent-first:

```bash
git config beads.workflow-mode agent
```

### 4. Verify

```bash
source .beads/lib/bmad-aliases.sh
bd_health
```

Should report:
- `.bmad/SKILL.md` present
- `BMAD_MANIFEST.md` present
- Aliases v0.2.0
- All components healthy

### 5. Test Agent Workflow

```bash
bd prime
bd ready --json
# Should return available work as JSON
```

## What Happens to Existing Data

- **`.beads/` state**: Preserved (issues, config, database)
- **`_bmad/` installation**: Preserved (standard BMAD workflows)
- **Git hooks**: Extended (not replaced)
- **`.beads/AGENTS.md`**: Managed block updated, custom content preserved
- **`bd_*` wrapper functions**: Still available in aliases but deprecated

## Breaking Changes from v0.1.0

| v0.1.0 | v0.2.0 | Migration |
|--------|--------|-----------|
| `bd_claim "key"` | `bd update <id> --status in_progress --claim` | Use native bd |
| `bd_decision "..."` | `bd create "..." -t decision` | Use native bd |
| `bd_blocker "..."` | `bd create "..." -t blocker` | Use native bd |
| `bd_halt "..."` | `bd create "..." -t blocker --priority 0` | Use native bd |
| `bd_release <id>` | `bd close <id> --reason "done"` | Use native bd |
| `bd_done "key"` | `bd close <id> --reason "completed"` | Use native bd |
| `bd_sync_story <file>` | Create issues directly via `bd create` | No file parsing |
| `sprint-status.yaml` | `bd ready --json` | Beads owns work queue |

## Coexistence

`.bmad/` (agent methodology) and `_bmad/` (standard BMAD) coexist:
- `_bmad/`: Full BMAD workflows for interactive human use
- `.bmad/`: Condensed methodology for agent JIT-loading
- Both are valid — use whichever fits your workflow
