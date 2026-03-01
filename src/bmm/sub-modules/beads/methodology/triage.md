# Triage Checklist

Answer these 5 questions to determine scale level and process:

## 1. How many files will change?
- 1 file → likely L1
- 2-3 files → likely L2
- 4+ files → likely L3-L4

## 2. Are there design decisions to make?
- No (obvious solution) → L1-L2
- Yes (multiple valid approaches) → L3+

## 3. Does this change the architecture?
- No → L1-L3
- Yes (new patterns, new dependencies, new subsystems) → L4

## 4. How many people/agents need to coordinate?
- Just me → L1-L2
- 2-3 agents → L3
- Multiple agents across epics → L4

## 5. What's the risk if it goes wrong?
- Easy to revert → L1-L2
- Moderate impact → L3
- Hard to revert, affects many users → L4

## Decision Matrix

| Files | Design Decisions | Arch Change | Coordination | Risk | Level |
|-------|-----------------|-------------|-------------|------|-------|
| 1 | No | No | Solo | Low | L1 |
| 2-3 | No/Light | No | Solo | Low | L2 |
| 4+ | Yes | No | 2-3 agents | Med | L3 |
| Many | Yes | Yes | Multiple | High | L4 |

## After Triage
- L1: `bd create "title" -t task` → claim → fix → close
- L2: `bd create "title" -t task` → light plan → implement → close
- L3: `bd mol pour bmad-feature --args "title=..."` → follow phases
- L4: `bd mol pour bmad-feature --args "title=..."` per epic → coordinate
