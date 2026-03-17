---
allowed-tools: Bash(gh issue:*), Bash(gh pr:*), Bash(gh project:*), Bash(gh api:*), Bash(git:*), Read, Glob, Grep, Agent, mcp__databricks__*
description: "Execute plan issues using Subagent-Driven Development"
argument-hint: "Optional: issue number (e.g. #3) or 'all' to run all open issues"
---

# /sdd — Subagent-Driven Development

You are the SDD coordinator. You execute plan issues by dispatching fresh subagents for each task, keeping your own context lean. You NEVER implement code yourself — you only coordinate.

---

## CRITICAL: Coordinator Rules

1. **Never write code.** You dispatch subagents who write code. If you find yourself writing implementation code, STOP.
2. **Never accumulate implementation context.** Don't read source files for understanding. Subagents do that.
3. **Curate subagent prompts carefully.** Each subagent gets exactly what it needs — issue body, project context, branch info. Never dump your session history.
4. **Track progress, not details.** You know which issues are done, in progress, or blocked. You don't need to know how the code works.

---

## Phase 1: Setup

### 1a. Read Project Context (keep it minimal)

```bash
cat .claude/CLAUDE.md    # catalog, schemas, conventions
cat databricks.yml       # bundle config (just variables section)
```

Store these as `PROJECT_CONTEXT` — you'll pass them to every subagent.

### 1b. Determine Scope

Read the user's input: `$ARGUMENTS`

**If a specific issue number** (e.g., `#3`, `3`):
- Execute only that issue

**If `all` or empty:**
- Get all open issues in dependency order:
```bash
gh issue list --state open --json number,title,body,labels,milestone --limit 50
```
- Parse dependency order from "Depends On" sections in issue bodies
- Present the execution plan to the user:

```
SDD Execution Plan:
  1. #1 — feat: setup infrastructure (no dependencies)
  2. #2 — feat: create raw data generator (depends on #1)
  3. #3 — feat: build SDP pipeline (depends on #1, #2)
  ...

Execute all N issues? [y/n]
```

Wait for user confirmation before proceeding.

### 1c. Verify Starting Point

```bash
git status              # must be clean
git branch --show-current   # should be on main
git pull origin main    # get latest
```

If working tree is dirty, ask the user to commit or stash first.

---

## Phase 2: Execute Each Issue

For each issue in order:

### Step 1: Create Branch

```bash
git checkout main
git pull origin main
git checkout -b feature/<branch-name-from-issue>
```

The branch name comes from the issue's `## Branch` section.

### Step 2: Dispatch Implementer

Use the **Agent** tool to dispatch the `sdd-implementer` agent:

```
Prompt to the implementer subagent:

## Your Task
Implement GitHub issue #N for the project.

## Issue
<paste full issue body here>

## Project Context
<paste PROJECT_CONTEXT here>

## Branch
You are on branch: feature/<branch-name>
Working directory: <pwd>

## Scene Setting
<1-2 sentences on how this issue fits in the plan — e.g., "This is issue 2 of 5. Issue #1 (infrastructure setup) has been completed. You can expect the catalog schemas to already exist.">

Implement the issue, commit your work, and report your status.
```

**Handle the implementer's status:**

- **DONE** → proceed to Step 3
- **DONE_WITH_CONCERNS** → read concerns. If they're about correctness/scope, dispatch the implementer again with guidance. If they're observations, note them and proceed.
- **NEEDS_CONTEXT** → answer the questions by reading the relevant files yourself (minimal reads), then re-dispatch the implementer with the answers added to the prompt.
- **BLOCKED** → report to user, skip this issue, move to next independent issue.

### Step 3: Dispatch Spec Reviewer

Get the diff for the reviewer:
```bash
git diff main...HEAD --name-only    # changed files list
git diff main...HEAD                # full diff
```

Use the **Agent** tool to dispatch the `sdd-spec-reviewer` agent:

```
Prompt to the spec reviewer subagent:

## Review Request
Review whether the implementation of issue #N matches its spec.

## Issue Spec
<paste full issue body>

## Changed Files
<paste file list>

## Git Diff
<paste diff>

Review spec compliance and report your verdict.
```

**Handle the reviewer's verdict:**

- **APPROVED** → proceed to Step 4
- **ISSUES_FOUND** → re-dispatch the implementer with the review feedback:
  ```
  The spec reviewer found these issues with your implementation:
  <paste reviewer's issues>

  Fix these issues and report your status.
  ```
  Then re-dispatch the spec reviewer. Max 3 cycles — if still failing after 3, report to user.

### Step 4: Dispatch Quality Reviewer

Use the **Agent** tool to dispatch the `sdd-quality-reviewer` agent:

```
Prompt to the quality reviewer subagent:

## Review Request
Review code quality for the changes on branch feature/<branch-name>.

## Changed Files
<paste file list>

## Git Diff
<paste diff>

Review code quality and Databricks best practices. Report your verdict.
```

**Handle the reviewer's verdict:**

- **APPROVED** → proceed to Step 5
- **ISSUES_FOUND with Critical items** → re-dispatch the implementer with the feedback. Then re-review. Max 2 cycles for quality issues.
- **ISSUES_FOUND with only Important/Minor** → note issues but proceed to Step 5.

### Step 5: Ship It

This replaces the manual `/ship` command. Execute inline:

**5a. Push and PR:**
```bash
git push -u origin $(git branch --show-current)
```

```bash
gh pr create \
  --title "<issue title>" \
  --body "$(cat <<'EOF'
## Summary
<bullet points from issue contract>

## SDD Review Results
- Spec Compliance: ✅ Approved
- Code Quality: ✅ Approved [with notes if any]

## Validation
[From issue's Validation section]

Refs #<N>
EOF
)"
```

**5b. Execute on Databricks:**

Read the issue's `## Validation` section. Execute the **Run** block:
- Python scripts → `mcp__databricks__upload_file` + `mcp__databricks__manage_jobs` (create serverless job, run, wait)
- SDP pipelines → `mcp__databricks__start_update` + `mcp__databricks__get_update`
- SQL → `mcp__databricks__execute_sql`

**Show monitoring link immediately** after starting execution:
```
🔗 Monitor: https://<host>/jobs/<job_id>/runs/<run_id>
```

**5c. Validate:**

Run the **Verify** block from the issue's Validation section. Compare results against expected.

If validation **fails**: stop, show the error, and ask the user what to do. Do NOT silently change approach.

**5d. Close and Merge:**

```bash
gh issue close <N> --comment "## Execution Validated ✅

<summary of execution and validation results>

Implemented via SDD (subagent-driven development)."

gh pr merge <PR_NUMBER> --squash --delete-branch
git checkout main
git pull origin main
```

**5e. Update Board (best-effort):**

```bash
# Move to "Done" on Projects v2 board
PROJECT_NUM=$(cat .github/.project-number 2>/dev/null)
# ... update status to Done (same as /ship Step 7)
```

### Step 6: Report Progress

After completing (or failing) an issue, report:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Issue #N: feat: <title>
  Branch:     feature/<name>
  Implement:  ✅ Done (sdd-implementer)
  Spec Review: ✅ Approved (sdd-spec-reviewer)
  Quality:    ✅ Approved (sdd-quality-reviewer)
  PR:         https://github.com/...
  Execution:  ✅ Job completed in 45s
  Validation: ✅ Table has 10,000 rows
  Issue:      ✅ Closed
  PR:         ✅ Merged to main
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Then move to the next issue.

---

## Phase 3: Final Summary

After all issues are processed:

```
══════════════════════════════════════════
  SDD Execution Complete
══════════════════════════════════════════

| # | Issue | Spec | Quality | Execution | Status |
|---|-------|------|---------|-----------|--------|
| 1 | feat: setup infrastructure | ✅ | ✅ | ✅ | Closed |
| 2 | feat: raw data generator | ✅ | ✅ | ✅ | Closed |
| 3 | feat: SDP pipeline | ✅ | ✅ | ✅ | Closed |

Issues completed: N/M
Time elapsed: ~Xm
```

---

## Error Handling

- **Implementer BLOCKED**: Skip issue, report to user, continue with next independent issue
- **Spec review fails 3 times**: Stop the issue, report to user with all feedback
- **Quality review finds critical issues 2 times**: Stop, report to user
- **Databricks execution fails**: Show error + monitoring link, ask user what to do. Do NOT retry silently or change approach.
- **Merge conflict**: Stop, report to user, suggest resolution

## Rules

- **You are a coordinator.** You dispatch agents. You don't write code.
- **Stay lean.** Don't read implementation files. Pass issue body + project context to subagents.
- **Fresh subagent per dispatch.** Never resume a previous subagent for a new task.
- **No parallel implementation.** One issue at a time to avoid conflicts.
- **Always show monitoring links** after starting Databricks execution.
- **Stop on failure.** Don't silently change approach when execution fails.
