# BMAD 4-Phase Model

## Phase 1: Analysis
**Goal**: Understand the problem space and validate the opportunity.

**Activities**: Market research, domain research, technical feasibility, competitive analysis, product brief creation.

**Agents**: Analyst (Mary)

**Gate**: Analysis complete — problem understood, opportunity validated, brief approved.

## Phase 2: Planning
**Goal**: Define what to build with clear requirements.

**Activities**: PRD creation through user interviews, requirements discovery, PRD validation, stakeholder alignment.

**Agents**: Product Manager (John)

**Gate**: Planning complete — PRD approved, requirements clear, scope locked.

## Phase 3: Solutioning
**Goal**: Design the technical solution and prepare for implementation.

**Activities**: Architecture design, technology selection, epics/stories creation, implementation readiness check.

**Agents**: Architect (Winston), PM (John)

**Gate**: Solutioning complete — architecture approved, stories ready, implementation readiness verified.

## Phase 4: Implementation
**Goal**: Build, test, and deliver the solution.

**Activities**: Sprint planning, story creation with context, development, code review, retrospective.

**Agents**: Scrum Master (Bob), Developer (Amelia), QA (Quinn)

**Gate**: Implementation complete — all stories done, tests passing, review complete.

## Phase Transitions
Phases are sequential. Each gate must pass before proceeding. Use `bd create "Gate: {phase} complete" -t gate` to track transitions in Beads.

Skipping phases is allowed at L1-L2 scale levels (see scale-levels.md).
