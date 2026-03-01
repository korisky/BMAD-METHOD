# BMAD Scale Levels

## L1: Quick Fix
**Scope**: Single file change, typo fix, config tweak, obvious bug.
**Process**: Direct fix. No formal phases needed.
**Beads**: Single task, claim → fix → close.
**Skip**: All phases — just do it.

## L2: Light Feature
**Scope**: Small feature, 1-3 files, clear requirements, no architectural decisions.
**Process**: Light plan → implement → verify.
**Beads**: Task group, optional molecule.
**Skip**: Analysis and formal solutioning. Brief planning sufficient.

## L3: Standard Feature
**Scope**: Multi-file feature, needs design decisions, moderate complexity.
**Process**: Full 4-phase BMAD workflow.
**Beads**: Pour `bmad-feature` molecule. Gates enforce phase transitions.
**Skip**: Nothing — follow all phases.

## L4: Major Initiative
**Scope**: Cross-cutting changes, new subsystem, multiple epics, architectural impact.
**Process**: Full 4-phase with extra rigor. Multiple epics, formal architecture review.
**Beads**: Pour `bmad-feature` molecule per epic. Coordinate via dependencies.
**Skip**: Nothing — add extra review gates between epics.

## Determining Scale Level
Use the triage checklist: .bmad/methodology/triage.md
