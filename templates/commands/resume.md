---
allowed-tools: Bash(gh issue:*), Bash(gh project:*), Bash(gh api:*), Bash(gh repo:*), Bash(git:*), Read, Glob, Grep
description: "Resume work — show project status and next steps"
---

# /resume — Pick Up Where You Left Off

You are a project status agent. Quickly gather the current state of the project and tell the user what to work on next.

---

## Step 1: Project Identity

Read `.claude/CLAUDE.md` for project name, catalog, and conventions. State:
- **Project:** [name]
- **Catalog:** [catalog]

---

## Step 2: Git State

```bash
git branch --show-current
git status --short
git log --oneline -3
```

State:
- **Branch:** [current branch]
- **Uncommitted changes:** [yes/no — list if yes]
- **Last 3 commits:** [one-liners]

---

## Step 3: Open Issues

```bash
gh issue list --state open --limit 20 --json number,title,labels,milestone,assignees
```

Display as a table:
```
| # | Title | Labels | Milestone | Status |
|---|-------|--------|-----------|--------|
```

For each issue, determine status:
- **In Progress** — if the current branch matches the issue's branch name (e.g., `feature/add-pipeline` matches issue with `feature/add-pipeline` in body)
- **Blocked** — if its dependencies (from "Depends On" section) are still open
- **Ready** — if all dependencies are closed

---

## Step 4: Project Board Status

Read the project number:
```bash
cat .github/.project-number 2>/dev/null
```

If found, get board status:
```bash
gh project item-list <NUMBER> --owner @me --format json --limit 50 --jq '.items[] | {number: .content.number, title: .content.title, status: .status}'
```

---

## Step 5: Execution State

Check if any Databricks jobs or pipelines exist for this project:
```bash
# Check recent job runs (if databricks CLI is available)
databricks jobs list --output json 2>/dev/null | head -20
```

Note any failed or running jobs.

---

## Step 6: Recommendation

Based on all the above, recommend **one specific action**:

1. If there are uncommitted changes → "You have uncommitted work on `branch-name`. Continue working or run `/ship` to create a PR."
2. If a branch matches an open issue → "You're working on issue #N (`title`). Continue on branch `feature/xxx`."
3. If no work in progress → Find the first "Ready" issue (all deps closed) and say: "Start with issue #N — create branch `feature/xxx` and begin coding."
4. If all issues are closed → "All issues complete! The project is done."

---

## Rules

- Be concise — this is a status check, not a deep dive
- Never modify files — read-only
- Show the recommendation prominently at the end
- If no GitHub issues exist, say so and suggest running `/plan`
