---
allowed-tools: Bash(git:*), Bash(gh issue:*), Bash(gh project:*), Read, Write, Glob, Grep
description: "Save current work state for the next session"
---

# /pause — Save State for Next Session

You are a state-capture agent. Save everything the next session needs to pick up where you left off.

### ⛔ FORBIDDEN:
- **Do NOT use the Agent tool.** No subagents. Run all steps sequentially.
- **Do NOT use the Skill tool.** This is a command file, not a skill.

---

## Step 1: Capture State

Gather current state silently (no output yet):

```bash
BRANCH=$(git branch --show-current)
STATUS=$(git status --short)
LAST_COMMITS=$(git log --oneline -5)
OPEN_ISSUES=$(gh issue list --state open --json number,title --limit 20 2>/dev/null)
CLOSED_ISSUES=$(gh issue list --state closed --json number,title --limit 20 2>/dev/null)
OPEN_PRS=$(gh pr list --state open --json number,title,headRefName --limit 5 2>/dev/null)
```

---

## Step 2: Write CONTINUE-HERE.md

Create `CONTINUE-HERE.md` at the project root:

```markdown
# Continue Here

## Session State (saved at [timestamp])

### Git
- **Branch:** [current branch]
- **Uncommitted files:** [list or "none"]
- **Last 5 commits:** [one-liners]

### Open PRs
[list any open PRs with their branch names]

### Issues
- **Closed:** [list closed issue numbers + titles]
- **Open:** [list open issue numbers + titles]
- **Currently working on:** [issue number if branch matches, or "none"]
- **Next unblocked:** [first issue with all deps met]

### What Was Happening
[1-2 sentences about what you were doing when /pause was called — infer from branch name, uncommitted changes, and last commits]

### What To Do Next
[Specific instruction for the next session — e.g., "Continue building issue #3 on branch feature/xxx" or "Run /ship to finalize issue #2" or "Merge PR #6 then start issue #3"]
```

---

## Step 3: Commit and Push

```bash
git add CONTINUE-HERE.md
git commit -m "chore: save work state via /pause"
git push
```

---

## Step 4: Confirm

Tell the user:

```
Work state saved to CONTINUE-HERE.md.
Next session: run /resume to pick up where you left off.
```

---

## Rules

- Keep CONTINUE-HERE.md under 50 lines — it's a checkpoint, not a document
- Always commit and push so the state survives machine switches
- Never modify any code files — this is a read-only + write-one-file operation
