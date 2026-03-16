---
allowed-tools: Bash(git:*), Read, Glob, Grep, Write, Edit
description: "Save current work state to CONTINUE-HERE.md for next session"
---

# /pause-work — Capture State for Next Session

You are a session handoff agent. Capture the current work state so the next Claude session can pick up exactly where you left off.

---

## Step 1: Gather Context

Run these in parallel:

```bash
git branch --show-current
git status --short
git log --oneline -5
git diff --stat
```

Also read:
- `.claude/CLAUDE.md` or `CLAUDE.md` for project identity
- Any open TODO list or plan files in `.claude/plans/`

---

## Step 2: Summarize Current Work

Determine:
- **What task is in progress** (from conversation context, branch name, recent commits)
- **What's already done** (completed items, committed code)
- **What's remaining** (next steps, blockers, known issues)
- **Key files touched** (from git diff/status)
- **Important decisions made** (architectural choices, workarounds discovered)

---

## Step 3: Write CONTINUE-HERE.md

Write a `CONTINUE-HERE.md` file in the project root with this structure:

```markdown
# Continue Here

**Last active:** [YYYY-MM-DD HH:MM]
**Branch:** [branch name]
**Task:** [one-line summary]

## What's Done
- [completed item 1]
- [completed item 2]

## What's Left
- [ ] [next step 1]
- [ ] [next step 2]
- [ ] [next step 3]

## Key Files
- `path/to/file1.py` — [what was changed/created]
- `path/to/file2.sql` — [what was changed/created]

## Context & Decisions
- [important decision or workaround]
- [gotcha discovered during work]

## How to Resume
[Specific instruction for the next session, e.g., "Run /ship to finish PR for issue #5" or "Continue implementing the cleansed layer — start with sessionization logic in src/cleansed/sessions.py"]
```

---

## Step 4: Confirm

After writing the file, tell the user:
- File saved at `CONTINUE-HERE.md`
- Summary of what's captured
- "Next session: just say 'pick up where I left off' or run `/resume-work`"

---

## Rules

- Be specific — vague summaries are useless to the next session
- Include exact file paths, not descriptions
- Include branch name and uncommitted changes status
- Don't commit CONTINUE-HERE.md — it's ephemeral session state
- If there's nothing in progress, say so and skip writing the file
