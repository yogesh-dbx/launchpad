---
allowed-tools: Bash(gh issue:*), Bash(gh project:*), Bash(gh api:*), Bash(gh repo:*), Bash(git:*)
description: "Resume work — show project status and next steps"
---

# /resume — Pick Up Where You Left Off

You are a project status agent. Gather state in two parallel batches, then produce a single concise output.

---

## Step 1: Gather Everything in Parallel

Run ALL of these simultaneously:

```bash
# Batch A — git
git branch --show-current && git status --short && git log --oneline -5

# Batch B — all issues (closed + open) in one call
gh issue list --state all --limit 30 --json number,title,state,labels,milestone,closedAt

# Batch C — open PRs
gh pr list --state open --json number,title,headRefName,state --limit 5
```

---

## Step 2: Produce One Unified Table

Merge closed and open issues into **one table**, sorted by issue number ascending:

```
| #  | Title                  | Milestone | Status      |
|----|------------------------|-----------|-------------|
| ✅ #1 | chore: bootstrap    | M1        | Shipped     |
| ✅ #2 | feat: design skill  | M1        | Shipped     |
| 🔄 #5 | feat: APX frontend  | M2        | In Progress |
| 📋 #6 | test: unit tests    | M3        | Ready       |
| ⛔ #8 | feat: ...           | M3        | Blocked     |
```

Status rules:
- **✅ Shipped** — issue state is `CLOSED`
- **🔄 In Progress** — issue is open AND current git branch matches its feature branch
- **⛔ Blocked** — issue is open AND its "Depends On" issues are still open
- **📋 Ready** — issue is open, all deps closed, not current branch

Below the table, one line for git state:
```
Branch: feature/apx-frontend | Uncommitted: yes (6 new components, modified backend) | Last commit: abc1234 feat: ...
```

If there's an open PR: add one line:
```
Open PR: #11 feature/apx-frontend — mergeable
```

---

## Step 3: Recommendation

One short paragraph. Pick the highest-priority action:

1. Open PR for a closed issue → merge it: `gh pr merge <N> --squash --delete-branch`
2. Uncommitted changes on feature branch → "Commit and run `/ship`"
3. On a feature branch matching an open issue → "Continue issue #N or run `/ship`"
4. On main, no WIP → "Start issue #N — `git checkout -b feature/xxx`"
5. All closed → "All done! 🎉"

---

## Rules

- **Two bash calls max** — batch A and batch B run in parallel, batch C in parallel with them. Never make sequential calls for data you could fetch at once.
- **One table** — no separate "Shipped" and "Open" sections
- **No section headers for git/PR** — inline after the table
- **Recommendation is 2-4 lines max** — specific, actionable, no recap
- Never modify files — read-only
