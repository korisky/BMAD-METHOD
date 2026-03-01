# Beads Integration Sub-Module (Agent-First)

## Overview

This sub-module integrates [Beads](https://github.com/steveyegge/beads) with the BMAD Method for **agent-first** workflow coordination. Beads owns all work state (tasks, blockers, decisions, gates), while BMAD provides methodology templates loaded on-demand.

## Architecture

```
Target Project (after installation):
├── .bmad/           # Agent methodology (personas, templates, methodology)
│   ├── SKILL.md     # JIT bootstrap (<300 tokens)
│   ├── personas/    # Condensed agent personas (<200 tokens each)
│   ├── templates/   # BMAD methodology templates
│   └── methodology/ # Phase model, scale levels, triage, quality gates
├── .beads/          # Beads state (created by bd init)
│   ├── formulas/    # Molecule templates (bmad-feature, bmad-bugfix)
│   └── AGENTS.md    # Agent-first protocol reference
├── BMAD_MANIFEST.md # Universal agent discovery file
└── _bmad/           # Standard BMAD install (upstream workflows/agents)
```

## Agent Session Lifecycle

1. **Start**: `bd prime` → `bd ready --json`
2. **Claim**: `bd update <id> --status in_progress --claim --json`
3. **Work**: Load `.bmad/personas/{role}.md` and `.bmad/templates/{type}.md` on-demand
4. **Track**: `bd create "title" -t <type>` for blockers, decisions, gates
5. **Close**: `bd close <id> --reason "summary" --json`
6. **Sync**: `bd sync` before ending session

## Key Differences from ver_0.1.0

- **Unified state**: Beads owns ALL work state (no split with sprint-status.yaml)
- **Native commands**: Agents use `bd` directly (no `bd_claim`, `bd_decision` wrappers)
- **JIT loading**: SKILL.md bootstraps, methodology loaded on-demand (not all at once)
- **Molecules**: BMAD phases encoded as Beads formulas (`.beads/formulas/`)
- **Gates**: Phase transitions tracked as Beads gate issues

## Installation

This sub-module is installed via the BMAD CLI:

```bash
npx bmad-beads install  # Includes "Enable Beads integration?" prompt
```

Or manually:

```bash
bash src/bmm/sub-modules/beads/install.sh /path/to/target-project
```
