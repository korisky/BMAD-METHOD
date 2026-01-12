# BMAD + Beads Agent Instructions

> **Principle**: BMAD owns formal workflow outputs. Beads owns runtime state.

---

## The Split

```
BMAD owns:
├── Documents (PRD, Architecture, Stories)
├── Story status (sprint-status.yaml)
├── Phase progress (bmm-workflow-status.yaml)
└── ADRs (in architecture.md)

Beads owns:
├── Runtime decisions (outside workflows)
├── Blockers (external impediments)
└── Cross-story dependencies
```

**Key**: Don't duplicate. BMAD workflows capture their outputs. Beads captures what happens BETWEEN workflows.

---

## When to Use Beads

### Runtime Decisions (made OUTSIDE formal workflows)

| Use Beads? | Scenario |
|------------|----------|
| **No** | Architect picks GraphQL (captured in ADR) |
| **Yes** | DEV discovers mid-story: "need to refactor auth first" |
| **Yes** | PM says during implementation: "drop feature X" |
| **Yes** | SM decides: "defer this story to next sprint" |

```bash
bd create --title "Runtime: {summary}" --type decision
bd update <id> --notes "WHO: {agent} | WHAT: {choice} | WHY: {reason} | DOC: {affected_doc}"
```

### Blockers (external impediments)

```bash
bd create --title "Blocked: {issue}" --type blocker
bd update <id> --notes "AFFECTS: {story} | OWNER: {who} | ETA: {when}"
```

### Cross-Story Dependencies

```bash
bd create --title "Dep: {story-B} needs {story-A}" --type blocker
bd update <id> --notes "BLOCKED: {B} | NEEDS: {A} done first | REASON: {why}"
```

---

## When NOT to Use Beads

| Don't Do | Why | BMAD Handles It |
|----------|-----|-----------------|
| "Phase: PRD Complete" epic | Duplicate | bmm-workflow-status.yaml |
| Decision for each ADR | Duplicate | architecture.md |
| Issues for stories | Duplicate | sprint-status.yaml |
| Issues for tasks | Duplicate | Story file checkboxes |

---

## Session Start

```bash
# 1. Beads auto-primes (hook)

# 2. Check runtime state
bd list --type decision --status open
bd list --type blocker --status open

# 3. Find work from BMAD
# Read bmm-workflow-status.yaml (phase progress)
# Read sprint-status.yaml (story status)
# Load the active story file
```

---

## Session End ("Land the Plane")

```bash
# 1. BMAD workflows auto-update their status files

# 2. Beads sync
bd sync

# 3. Commit and push (MANDATORY)
git add -A
git commit -m "{message}"
git push

# 4. Verify
git status    # Must show "up to date"
```

---

## Trigger Phrases

| Say | Action |
|-----|--------|
| "what runtime decisions?" | `bd list --type decision` |
| "what's blocked?" | `bd list --type blocker` |
| "file that as runtime decision" | `bd create --type decision` |
| "that's a blocker" | `bd create --type blocker` |
| "land the plane" | Session close |

---

## 4 Rules

1. **Formal decisions → ADRs** (BMAD architecture.md)
2. **Runtime decisions → Beads** (outside workflow changes)
3. **Blockers → Beads** (external impediments)
4. **Push before done** (work not saved until pushed)

---

`bd help` | `bd quickstart` | `bd doctor`
