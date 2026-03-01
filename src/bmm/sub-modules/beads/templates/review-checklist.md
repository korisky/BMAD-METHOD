# Code Review Checklist

## Story Reference
- **Story**: {story-id}
- **Reviewer**:
- **Date**:

## Correctness
- [ ] Implementation matches acceptance criteria
- [ ] Edge cases handled
- [ ] Error handling appropriate
- [ ] No logic errors

## Tests
- [ ] Unit tests exist for new code
- [ ] Tests cover happy path and edge cases
- [ ] All tests pass (no skipped tests)
- [ ] No test regressions

## Code Quality
- [ ] Code follows project conventions
- [ ] No unnecessary complexity
- [ ] Functions have single responsibility
- [ ] No dead code or commented-out blocks

## Security
- [ ] No hardcoded secrets or credentials
- [ ] Input validation at system boundaries
- [ ] No injection vulnerabilities (SQL, XSS, command)
- [ ] Auth/authz checks in place where needed

## Performance
- [ ] No obvious N+1 queries or unnecessary loops
- [ ] Resources properly cleaned up
- [ ] No memory leaks

## Review Follow-ups
<!-- Items discovered during review that need action -->
- [ ] {item}
