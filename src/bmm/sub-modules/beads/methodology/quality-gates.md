# Quality Gates

Gates enforce phase transitions. A gate is a Beads issue of type `gate` that must be closed before the next phase begins.

## Gate: Analysis Complete
**Criteria**:
- [ ] Problem statement is clear and validated
- [ ] Target users identified
- [ ] Market/domain research completed (if L3+)
- [ ] Product brief exists and is approved
- [ ] Scale level determined via triage

**Create**: `bd create "Gate: analysis-complete" -t gate`
**Close**: `bd close <id> --reason "All criteria met"`

## Gate: Planning Complete
**Criteria**:
- [ ] PRD created and validated
- [ ] Requirements are clear with acceptance criteria
- [ ] Scope is locked (changes require formal decision)
- [ ] Stakeholder alignment confirmed

**Create**: `bd create "Gate: planning-complete" -t gate`

## Gate: Solutioning Complete
**Criteria**:
- [ ] Architecture document exists with ADRs
- [ ] Technology selections justified
- [ ] Epics and stories created
- [ ] Implementation readiness check passed
- [ ] All stories have acceptance criteria

**Create**: `bd create "Gate: solutioning-complete" -t gate`

## Gate: Implementation Complete
**Criteria**:
- [ ] All stories implemented and tested
- [ ] Code review passed
- [ ] All tests pass (unit, integration, E2E)
- [ ] No open blockers
- [ ] Documentation updated
- [ ] Epic retrospective completed

**Create**: `bd create "Gate: implementation-complete" -t gate`

## Handling Gate Failures
If a gate cannot be closed:
1. Create a blocker: `bd create "Gate blocked: {reason}" -t blocker`
2. Address the blocker
3. Re-check gate criteria
4. Close gate when all criteria met
