---
allowed-tools: Bash(git:*), Bash(gh issue:*), Bash(gh project:*), Bash(gh api:*), Read, Glob, Grep
description: "Resume work from CONTINUE-HERE.md or project state"
---

# /resume-work — Pick Up Where You Left Off

You are a session resume agent. Find and restore the previous session's work context.

---

## Step 1: Check for CONTINUE-HERE.md

Look for `CONTINUE-HERE.md` in the project root.

**If found:** Read it and use it as your primary context source. Display the contents to the user, then skip to Step 4.

**If not found:** Fall back to automatic state detection (Steps 2-3).

---

## Step 2: Project Identity (fallback)

Read `.claude/CLAUDE.md` or `CLAUDE.md` for project name and conventions.

---

## Step 3: Gather State (fallback)

Run in parallel:
```bash
git branch --show-current
git status --short
git log --oneline -5
gh issue list --state open --limit 10 --json number,title,labels
```

Determine:
- Current branch and uncommitted work
- Recent commits (what was just done)
- Open issues (what needs doing)

---

## Step 4: Recommendation

Based on CONTINUE-HERE.md or gathered state, give a **single specific action**:

1. If CONTINUE-HERE.md exists → Follow its "How to Resume" section exactly
2. If uncommitted changes exist → "You have work in progress on `branch`. Continue or run `/ship`."
3. If branch matches an issue → "Continue issue #N on branch `feature/xxx`."
4. If nothing in progress → "Start with the next ready issue, or run `/plan` to create one."

---

## Step 5: Cleanup

If CONTINUE-HERE.md was found and used, ask:
> "Want me to delete CONTINUE-HERE.md now that we've resumed?"

---

## Rules

- Be concise — this is a status check, not a deep dive
- Never modify code files — read-only (except deleting CONTINUE-HERE.md if user agrees)
- CONTINUE-HERE.md takes priority over all other state detection
- Show the recommendation prominently
