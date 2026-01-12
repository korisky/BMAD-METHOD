# BMAD + Beads Agent Instructions

> **Principle**: BMAD owns documents + status. Beads owns decisions + blockers. No overlap.

---

## The Split

```
BMAD = Documents + Story Status (sprint-status.yaml)
Beads = Decisions + Dependencies + Blockers
```

**Why**: BMAD already tracks stories perfectly. Beads adds what BMAD can't do: persistent decisions and dependency tracking.

---

## Quick Reference

### BMAD (Story Status)
```bash
# Find what to work on
cat {implementation}/sprint-status.yaml
# Look for "ready-for-dev" status
```

### Beads (Decisions & Blockers)
```bash
bd list --type decision    # What choices were made?
bd list --type blocker     # What's blocked?
bd create --type decision  # Record a choice
bd create --type blocker   # Record impediment
bd sync                    # Sync with git
```

---

## When to Use Beads

**Create a decision issue when:**
- You choose between alternatives (e.g., "GraphQL over REST")
- You narrow scope (e.g., "Removing feature X")
- You make a tradeoff (e.g., "Speed over accuracy")
- The choice affects other agents

```bash
bd create --title "Decision: {summary}" --type decision --priority 2
bd update <id> --notes "WHO: {agent} | WHAT: {choice} | WHY: {rationale} | DOC: {path}"
```

**Create a blocker issue when:**
- External dependency stops work
- Need decision from someone else
- Technical impediment discovered

```bash
bd create --title "Blocked: {issue}" --type blocker --priority 1
bd update <id> --notes "AFFECTS: {story} | OWNER: {who} | DOC: {related_doc}"
```

**Create a phase issue at boundaries:**
```bash
bd create --title "Phase: PRD Complete" --type epic
bd update <id> --notes "DOC: docs/prd.md | FRs: {n}"
```

---

## When NOT to Use Beads

- Individual story tracking → use sprint-status.yaml
- Task checkboxes → use story file `[ ]` marks
- Code review comments → use PR system
- Requirements details → live in PRD/Architecture docs

---

## Session Start

```bash
# 1. Beads auto-primes on session start (hook)

# 2. Check for decisions and blockers
bd list --type decision --status open
bd list --type blocker --status open

# 3. Find work from BMAD
# Read sprint-status.yaml, find first ready-for-dev
# Load that story file
```

---

## Session End ("Land the Plane")

**Work is NOT complete until pushed.**

```bash
# 1. Update sprint-status.yaml if needed

# 2. Sync and commit
bd sync
git add -A
git commit -m "{message}"

# 3. Push (MANDATORY)
git push

# 4. Verify
git status    # Must show "up to date"

# 5. Handoff
bd list --type decision --status open
bd list --type blocker --status open
```

---

## Context Recovery (After /clear)

```bash
# 1. Beads context auto-loads

# 2. Get decisions
bd list --type decision
bd show <id>              # Notes have DOC: path

# 3. Get blockers
bd list --type blocker

# 4. Find current work
# Read sprint-status.yaml, find in-progress story
# Read that story file
```

---

## Human Trigger Phrases

| Say | Agent Does |
|-----|------------|
| "land the plane" | Session close → commit → push |
| "what decisions?" | `bd list --type decision` |
| "what's blocked?" | `bd list --type blocker` |
| "file that decision" | `bd create --type decision` |
| "that's a blocker" | `bd create --type blocker` |

---

## 5 Rules

1. **Stories → sprint-status.yaml** (not Beads)
2. **Decisions → Beads** (not scattered in docs)
3. **Blockers → Beads** (not buried in notes)
4. **DOC: path in notes** (enable recovery)
5. **Push before done** (work isn't saved until pushed)

---

`bd help` | `bd quickstart` | `bd doctor`
