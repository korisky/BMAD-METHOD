# Test Story File for bd_sync_story

## Tasks / Subtasks

- [ ] [AI-Review][HIGH] Fix authentication bug in login flow
- [ ] [AI-Review][MEDIUM] Add input validation for user registration
- [x] [AI-Review][LOW] Already done (should skip)
- [ ] Regular task without AI-Review tag (should skip)
- [ ] [AI-Review][LOW] Refactor error handling in API client

## Expected Results

When running: `bd_sync_story test-story-sync.md`

**Should create 3 tasks:**
1. "Fix authentication bug in login flow" (priority 0 - halt)
2. "Add input validation for user registration" (priority 1 - blocker)
3. "Refactor error handling in API client" (priority 2 - action)

**Should skip 2 items:**
1. Already completed item (has [x])
2. Regular task (no [AI-Review] tag)

**Task notes should contain:** "Story: test-story-sync"
