---
allowed-tools: Bash(gh issue:*), Bash(gh project:*), Bash(gh api:*), Bash(git:*), Read, Glob, Grep
description: "Show what's next — unblocked issues, parallel opportunities, board status"
---

# /next — What's Ready to Build?

You are a project status agent. You read the GitHub board, analyze dependencies, and tell the user exactly what's ready to work on.

---

## Step 1: Gather State

Run these commands to understand the current project state:

```bash
# Current branch
git branch --show-current

# All open issues with their bodies (need Depends On sections)
gh issue list --state open --json number,title,labels,body --limit 50

# All closed issues (these are "done")
gh issue list --state closed --json number,title --limit 50

# Any open PRs
gh pr list --state open --json number,title,headRefName --limit 10
```

## Step 2: Parse Dependencies

For each **open** issue, extract the "Depends On" section from the issue body:
- Look for lines matching `- #N` in the "Depends On" section
- Build a dependency map: `{issue_number: [list of dependency numbers]}`

An issue is **unblocked** if ALL its dependencies are in the closed issues list.
An issue is **blocked** if ANY dependency is still open.

## Step 3: Identify Parallel Opportunities

Among the unblocked issues, check if any are **independent** of each other (neither depends on the other, and they don't modify the same files based on their OUTPUT sections).

Independent unblocked issues can run in **parallel worktrees**.

## Step 4: Check Current Work

- Is there a feature branch checked out? → there might be work in progress
- Are there uncommitted changes? → current issue isn't shipped yet
- Is there an open PR? → current issue is in review

## Step 5: Present the Status

Output a clear status board:

```
📋 Project Status
═══════════════════════════════════════════════

Done (N):
  ✅ #1 — chore: setup infrastructure
  ✅ #2 — feat: generate synthetic data

In Progress:
  🔧 #3 — feat: build SDP pipeline (branch: feature/sdp-pipeline, uncommitted changes)

Blocked (N):
  🚫 #6 — feat: build dashboard (waiting on #4, #5)

Ready to Build (N):
  🟢 #4 — feat: train ML model
  🟢 #5 — feat: create Genie space

═══════════════════════════════════════════════
```

Then suggest the next action:

**If there's work in progress (uncommitted changes on a feature branch):**
> You have uncommitted work on `feature/sdp-pipeline` (issue #3). Run `/ship` to complete it, or continue building.

**If nothing is in progress and ONE issue is ready:**
> Next up: issue #4 — `feat: train ML model`
> Branch: `feature/ml-segmentation`
> Start with: `git checkout -b feature/ml-segmentation`

**If nothing is in progress and MULTIPLE independent issues are ready:**
> Two issues are ready and independent — you can run them in parallel:
>
> **Option 1: Sequential** (simpler)
> Start with #4 (`feature/ml-segmentation`), then #5 after shipping.
>
> **Option 2: Parallel worktrees** (faster)
> This session: `build issue #4`
> New terminal: `cd ../music_360 && git worktree add ../music_360-genie feature/genie-space && cd ../music_360-genie && claude`
> → "build issue #5"
>
> Both can run simultaneously since they're independent.

**If all issues are done:**
> 🎉 All issues complete! Run `/stats` for a velocity summary.

**If all remaining issues are blocked:**
> All remaining issues are blocked. Check the dependency chain — something may need to be unblocked first.

---

## Rules

- Never start building code in this command — only analyze and suggest
- Always show the full board status (done, in progress, blocked, ready)
- Always check for uncommitted work before suggesting new issues
- When suggesting parallel work, verify issues are truly independent (different files, different tables)
- Reference branch names from the issue body's `## Branch` section
- Keep output concise — the user wants a quick status check, not a deep analysis
