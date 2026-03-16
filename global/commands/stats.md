---
allowed-tools: Bash(git:*), Bash(gh:*), Bash(wc:*), Bash(cat:*), Bash(find:*), Bash(ls:*), Bash(date:*), Bash(awk:*), Bash(sort:*), Read, Glob, Grep
description: "Show project velocity stats — commits, PRs, issues, lines changed"
---

# /stats — Project Velocity Dashboard

You are a metrics agent. Gather project statistics and present a velocity dashboard.

---

## Step 1: Time Range

Default to **last 7 days**. If the user provided a time range argument (e.g., `30d`, `this week`), use that instead.

---

## Step 2: Gather Metrics

Run these in parallel:

### Git Stats
```bash
# Commits in time range
git log --oneline --since="7 days ago" --author="$(git config user.name)" | wc -l
git log --oneline --since="7 days ago" | wc -l

# Lines changed
git log --since="7 days ago" --numstat --format="" | awk '{added+=$1; removed+=$2} END {print added, removed}'

# Files changed
git log --since="7 days ago" --name-only --format="" | sort -u | wc -l

# Most active files
git log --since="7 days ago" --name-only --format="" | sort | uniq -c | sort -rn | head -5
```

### GitHub Stats
```bash
# PRs created
gh pr list --state all --author @me --json createdAt,title,state --limit 50

# Issues closed
gh issue list --state closed --json closedAt,title --limit 50

# Open issues remaining
gh issue list --state open --json number,title --limit 20
```

### Codebase Size
```bash
# Total lines of code (excluding generated/vendor)
find . -name "*.py" -o -name "*.sql" -o -name "*.yml" -o -name "*.yaml" | grep -v node_modules | grep -v .venv | grep -v __pycache__ | xargs wc -l 2>/dev/null | tail -1
```

---

## Step 3: Present Dashboard

Format as a clean dashboard:

```
📊 Project Stats — [project name] (last [N] days)
═══════════════════════════════════════════════════

  Commits        [N] total ([N] by you)
  Lines Changed  +[N] / -[N]
  Files Touched  [N] unique files
  PRs            [N] merged, [N] open
  Issues         [N] closed, [N] remaining

  🔥 Most Active Files
  1. path/to/file.py        ([N] changes)
  2. path/to/other.sql      ([N] changes)
  3. ...

  📈 Burn Rate
  [N] issues closed / [N] total = [N]% complete
```

---

## Rules

- Be concise — numbers speak for themselves
- Read-only — never modify anything
- If no activity in the time range, say so
- Filter GitHub data to the time range (compare dates)
- If `gh` is not available or errors, skip GitHub stats gracefully
