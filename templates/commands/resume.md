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

## Step 3: What's Been Shipped

Run in parallel:
```bash
gh issue list --state closed --limit 5 --json number,title,closedAt --sort updated --order desc
git log --oneline -5
```

Display both as tables:

```
| # | Title | Closed |
|---|-------|--------|
| ✅ #4 | feat: build APX backend | Mar 21 |
| ✅ #3 | feat: scaffold producer  | Mar 21 |

| Commit | Message |
|--------|---------|
| abc1234 | feat: build APX frontend (#5) |
| def5678 | feat: build APX backend (#4)  |
```

This gives the user immediate context on project momentum without digging through history.

---

## Step 4: Open Issues

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

## Step 5: Project Board Status

Read the project number:
```bash
cat .github/.project-number 2>/dev/null
```

If found, get board status:
```bash
gh project item-list <NUMBER> --owner @me --format json --limit 50 --jq '.items[] | {number: .content.number, title: .content.title, status: .status}'
```

---

## Step 6: Execution State

Check if any Databricks jobs or pipelines exist for this project:
```bash
# Check recent job runs (if databricks CLI is available)
databricks jobs list --output json 2>/dev/null | head -20
```

Note any failed or running jobs.

---

## Step 6.5: Pending PR Cleanup

Check for open PRs linked to already-closed issues — this means a previous `/ship` didn't finish the merge step:

```bash
gh pr list --state open --json number,title,headRefName,url --limit 10
```

For each open PR, check if its linked issue is closed:
```bash
# Extract issue number from PR branch (e.g., feature/seed-raw-listener-events → check recent closed issues)
gh issue list --state closed --limit 20 --json number,title
```

**If an open PR exists for a closed issue:**
- Tell the user: "PR #N is still open but issue #M is already closed. Merging to main now."
- Merge it: `gh pr merge <N> --squash --delete-branch`
- Pull main: `git checkout main && git pull --quiet`
- Commit any stray uncommitted files (tooling, config) with `chore: add project tooling`

**If no pending PRs:** continue to Step 6.

---

## Step 7: Recommendation

Based on all the above, recommend **one specific action**:

1. If there's a pending PR for a closed issue → merge it first (Step 6.5), then suggest next issue
2. If there are uncommitted changes on a feature branch → "You have uncommitted work on `branch-name`. Continue working or run `/ship`."
3. If a branch matches an open issue → "You're working on issue #N (`title`). Continue on branch `feature/xxx`."
4. If on main with no work in progress → Find the first "Ready" issue (all deps closed) and say: "Start with issue #N — create branch `feature/xxx` and begin coding."
5. If all issues are closed → "All issues complete! The project is done."

---

## Rules

- Be concise — this is a status check, not a deep dive
- Never modify files — read-only
- Show the recommendation prominently at the end
- If no GitHub issues exist, say so and suggest running `/plan`
