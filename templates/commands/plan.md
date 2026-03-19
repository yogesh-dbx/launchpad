---
allowed-tools: Bash(gh issue:*), Bash(gh label:*), Bash(gh project:*), Bash(gh api:*), Bash(gh repo:*), Bash(git:*), Read, Write, Glob, Grep
description: "Break down a use case into a plan with GitHub issues"
argument-hint: "Describe your use case, OR path to a doc (e.g. docs/use-case.md)"
---

# /plan — Use Case → Plan → GitHub Issues

You are a project planning agent. Given a use case description, you will:
1. Understand the requirements
2. Create a structured PLAN.md
3. Set up GitHub issues, labels, milestones, and Projects v2 board

---

## Phase 0: Resume Check (ALWAYS RUN FIRST)

**Before anything else**, check if a previous `/plan` session was interrupted (e.g., by context clear):

```bash
# Check if PLAN.md exists AND issues are missing
if [ -f PLAN.md ]; then
  echo "PLAN.md exists"
  OPEN_ISSUES=$(gh issue list --state open --limit 1 --json number --jq length 2>/dev/null || echo "0")
  CLOSED_ISSUES=$(gh issue list --state closed --limit 1 --json number --jq length 2>/dev/null || echo "0")
  echo "Open issues: $OPEN_ISSUES, Closed issues: $CLOSED_ISSUES"
fi
```

**If PLAN.md exists but there are ZERO issues (open + closed = 0):**
This means the plan was approved but GitHub setup never completed (session was cleared or interrupted).
- Tell the user: "Found PLAN.md but no GitHub issues. Resuming from Phase 3 — creating issues from the existing plan."
- Read PLAN.md
- Skip Phase 1 and Phase 2
- Jump directly to **Phase 3: Setup GitHub**
- Create all issues, milestones, board items from the existing PLAN.md

**If PLAN.md exists AND issues exist:**
The plan is already fully set up. Tell the user the current status:
- How many issues open vs closed
- Suggest: "Plan already exists with N issues. To re-plan, delete PLAN.md and run `/plan` again. To start building, say 'build issue #N'."
- STOP — do not re-plan.

**If PLAN.md does not exist:**
This is a fresh `/plan` run. Continue to Phase 1 normally.

---

## CRITICAL: Boundary Rules

**These rules apply for the ENTIRE session:**

1. **Confirm `.claude/CLAUDE.md` exists** before planning. If it doesn't exist, STOP and tell the user: "No `.claude/CLAUDE.md` found — run `gh-project-init` first." Do NOT read it until you have a use case (see Phase 1 Step 1).

2. **Verify your location.** Run `pwd` and `git remote get-url origin 2>/dev/null || echo 'no remote'`. Confirm the directory and repo name match the project you intend to plan. State them to the user.

3. **NEVER explore outside this project directory.** Do not read files in sibling directories (`../`), home directory projects, or any path outside `$(pwd)`. All context you need is in this project.

4. **Do NOT launch parallel exploration agents.** Read files sequentially using Read, Glob, and Grep. The project context is small — you do not need parallel agents to understand it.

5. **Keep exploration minimal.** Read at most: `.claude/CLAUDE.md`, `databricks.yml`, and a quick `ls src/ resources/` to see what exists. Do NOT read every source file. The plan is about WHAT to build, not HOW existing code works.

---

## Phase 1: Understand

### Step 1 — Input Check (BEFORE ANYTHING ELSE)

Read the user's input: `$ARGUMENTS`

**If `$ARGUMENTS` is empty or blank:**
- Quickly check if a default doc exists: `ls docs/use-case.md docs/USE_CASE.md docs/requirements.md USE_CASE.md 2>/dev/null`
- If a doc is found, use it as the use case and continue to Step 2.
- If NO doc is found, **STOP IMMEDIATELY** and ask the user:

> What would you like to build? Describe your use case, or provide a doc path:
> `/plan build a real-time analytics pipeline for gaming events`
> `/plan docs/use-case.md`

**Do NOT read CLAUDE.md, databricks.yml, or explore the project until you have a use case.** Wait for the user's response, then continue to Step 2.

**If `$ARGUMENTS` is a file path** (ends in `.md`, `.txt`, `.pdf`, `.docx`, or starts with `./`, `../`, `/`, `docs/`, `~`):
- Read the file and use its contents as the use case description.

**If `$ARGUMENTS` is inline text:**
- Use it directly as the use case description.

### Step 2 — Project Context (MANDATORY)

Now that you have a use case, read project context:
1. `.claude/CLAUDE.md` — catalog, schemas, conventions, failure conditions
2. `databricks.yml` — bundle name, targets, variables
3. `ls src/ resources/ 2>/dev/null` — what's already built (just filenames, don't read contents)
4. `PLAN.md` if it exists — previous plan state

State to the user:
- **Project:** [name from CLAUDE.md]
- **Catalog:** [catalog from CLAUDE.md]
- **Schemas:** raw, cleansed, curated
- **What exists:** [list of files in src/ and resources/]

### Step 3 — Clarifying Questions

After reading the use case AND project context, ask 2-4 clarifying questions ONLY if the use case is truly ambiguous:
- Who is the audience? (internal team, customer demo, production)
- Which Databricks services? (Unity Catalog, SDP, Model Serving, SQL Warehouse, Genie, Apps)
- Timeline constraints?
- Key modules or features to build?

If the use case is detailed enough, skip questions and proceed to Phase 2.

---

## Phase 2: Plan

Create `PLAN.md` at the project root with this structure:

```markdown
# Project Plan: [Goal]

## Overview
[2-3 sentences describing the project goal and approach]

## Architecture
[Key components, data flow, Databricks services used]

## Tech Stack
- Compute: Serverless
- Storage: Unity Catalog ({catalog}.raw / .cleansed / .curated)
- Pipelines: Spark Declarative Pipelines (SDP)
- Orchestration: Databricks Jobs / DABs
- [Other services as needed]

## Milestones

### M1: Data Foundation
- [ ] Task 1
- [ ] Task 2

### M2: [Next Phase]
- [ ] Task 3

## Orchestration
[Define a single DABs orchestration job that chains ALL tasks end-to-end]
- Job name: `{project_name}_orchestration`
- Task chain: task_key → depends_on → task_key
- Trigger: [schedule, manual, or CI/CD on deploy]
- Every pipeline and script MUST be a task in this job
- `databricks bundle deploy` creates the job; `databricks bundle run` or CI/CD triggers it

Example DABs resource:
```yaml
resources:
  jobs:
    orchestration:
      name: "${bundle.name}_orchestration"
      tasks:
        - task_key: step_1
          spark_python_task:
            python_file: src/step_1.py
        - task_key: step_2
          pipeline_task:
            pipeline_id: ${resources.pipelines.my_pipeline.id}
          depends_on:
            - task_key: step_1
```

## Dependency Graph
Task 1 → Task 2 → Task 3
Task 1 → Task 4
```

Present the plan to the user and **wait for approval** before proceeding.

---

## Phase 3: Setup GitHub

After user confirms the plan:

### 3a. Detect Assignees

Determine who should be assigned to issues:

```bash
# Get current user
ME=$(gh api user --jq '.login')

# Get all collaborators on the repo
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
COLLABS=$(gh api "repos/$REPO/collaborators" --jq '.[].login' 2>/dev/null)
COLLAB_COUNT=$(echo "$COLLABS" | wc -l | tr -d ' ')
```

**If solo contributor (only you):** Auto-assign all issues to `@me`. No prompt needed.
```bash
ASSIGNEE="$ME"
```

**If multiple contributors (2+):** Ask the user how to assign:
> I see N contributors on this repo: @user1, @user2, @user3
> How should issues be assigned?
> 1. Assign all to me (@user1)
> 2. Assign by milestone (I'll ask per milestone)
> 3. Leave unassigned (assign later)

If option 2 is chosen, ask for each milestone:
> Who should own M1: Data Foundation? [@user1 / @user2 / @user3]

Store the assignment mapping for use during issue creation.

### 3b. Read Project Number

First, pull latest changes (the project number may have been pushed from another session):
```bash
git pull --quiet 2>/dev/null || true
```

Then read the project number:
```bash
cat .github/.project-number
```

If the file doesn't exist or contains "PLACEHOLDER", try the API fallback — detect the project board by matching the repo name:
```bash
gh api graphql -f query='query { viewer { projectsV2(first: 20) { nodes { number title } } } }' --jq '.data.viewer.projectsV2.nodes[] | select(.title == "REPO_NAME") | .number'
```
(Replace `REPO_NAME` with the current repo name from `basename $(git remote get-url origin) .git`)

If a project number is found via API, save it locally:
```bash
echo "<number>" > .github/.project-number
```

If still not found, warn the user and continue without board integration.

### 3c. Create ALL Labels

**CRITICAL:** Create labels for ALL categories BEFORE creating any issues. If a label doesn't exist when `gh issue create --label` references it, the command **fails silently or errors**. Pre-create every `phase:*`, `priority:*`, and `module:*` label used in the plan.

```bash
# Phase labels — create ALL phases referenced in the plan
gh label create "phase:infra" --color "BFD4F2" --description "Infrastructure setup" --force
gh label create "phase:data" --color "C5DEF5" --description "Data pipeline phase" --force
gh label create "phase:ml" --color "D4C5F9" --description "ML model phase" --force
gh label create "phase:analytics" --color "FBCA04" --description "Analytics and visualization" --force
gh label create "phase:demo" --color "0E8A16" --description "Demo and documentation" --force
# Add more phase labels as needed for the specific plan

# Priority labels
gh label create "priority:critical" --color "D93F0B" --description "P0 — must have for MVP" --force
gh label create "priority:high" --color "E99695" --description "P1 — important" --force
gh label create "priority:medium" --color "FEF2C0" --description "P2 — nice to have" --force

# Module labels — from the plan's identified modules
gh label create "module:<name>" --color "C5DEF5" --description "<module description>" --force
```

Scan the PLAN.md milestones and issues to identify EVERY label that will be used, then create them all in one batch.

### 3d. Create Milestones
The `gh` CLI has **no `milestone` subcommand** — use the REST API instead.

For each milestone in the plan:
```bash
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
MILESTONE_NUMBER=$(gh api "repos/$REPO/milestones" --method POST \
  -f title="M1: Data Foundation" \
  -f description="Infrastructure and data pipeline setup" \
  --jq '.number')
```

Store each returned `number` for use in `--milestone` when creating issues.
If a milestone already exists (409 Conflict), query existing milestones to get its number:
```bash
MILESTONE_NUMBER=$(gh api "repos/$REPO/milestones" --jq '.[] | select(.title == "M1: Data Foundation") | .number')
```

### 3e. Create Issues (Dependency Order)

Create issues in **topological order** — prerequisites first, dependents after.

For each issue, use this body template:
```markdown
## Context
[1-2 sentences: WHY this issue exists, how it fits in the project]

## Contract
**GOAL:** [specific, testable outcome — what "done" looks like]
**CONSTRAINTS:** [Databricks services, compute type, naming conventions]
**OUTPUT:** [exact files to create/modify]
**EXECUTION:** [how this gets run — orchestration task, pipeline_task, schedule, or manual setup]
**FAIL IF:** [what makes this issue's output unacceptable]

## Components

### P0 — Must Have
- [ ] Component 1
- [ ] Component 2

### P1 — Important
- [ ] Component 3

### P2 — Nice to Have
- [ ] Component 4

## Databricks Services
- [Service 1]
- [Service 2]

## Depends On
> ⚠️ These issues must be completed before this one can start.
- #N — [Issue title]

## Execution
**TRIGGER:** [How this component gets executed — must be one of:]
- `orchestration job task` — runs as a task in the orchestration job (specify task_key and depends_on)
- `pipeline update` — triggered via `pipeline_task` in the orchestration job
- `schedule` — runs on a cron schedule (specify expression)
- `manual` — one-time setup, not part of recurring execution

**DABs resource snippet:**
```yaml
- task_key: <key>
  <task_type>: ...
  depends_on:
    - task_key: <upstream_key>
```

## Branch
`feature/short-description`

## Validation
**Run:**
- [exact command or MCP tool call to execute the artifact — e.g., `mcp__databricks__run_python_file_on_databricks` for scripts, `mcp__databricks__start_update` for pipelines, `mcp__databricks__execute_sql` for SQL]

**Verify:**
- [SQL query or check to confirm the output exists and is correct — e.g., `SELECT count(*) FROM catalog.schema.table`]
- [Expected result — e.g., "table has >0 rows", "schema has 3 columns", "dashboard renders"]

**Teardown:**
- [cleanup steps if any — e.g., delete one-time job, remove temp files. Or "none"]

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] **Execution validated** — orchestration job ran successfully with this component
- [ ] **Output verified** — expected tables/data/artifacts exist and are correct

## Closing Policy
> ⚠️ Do NOT close this issue on PR merge. Close ONLY after execution is validated.
> PRs should use `Refs #N`, never `Closes #N`.
```

Create each issue using a temp file for the body (avoids shell quoting issues with `#` in markdown):
1. Write the issue body to `/tmp/issue-body.md` using the Write tool
2. Create the issue referencing that file:
```bash
gh issue create \
  --title "feat: <title>" \
  --body-file /tmp/issue-body.md \
  --label "phase:<phase>,priority:<priority>,module:<module>" \
  --milestone "M1: Data Foundation" \
  --assignee "<ASSIGNEE>"
```
3. This avoids permission prompts from `#`-prefixed markdown headers in quoted strings.

### 3f. Add to Projects v2 Board and Set Status
For each created issue:
```bash
# Add to board
gh project item-add <PROJECT_NUMBER> --owner @me --url <ISSUE_URL>
```

After ALL issues are added, set their Status to "Todo" so they appear in the Board view:
1. Get the project node ID and Status field ID:
```bash
PROJECT_NODE_ID=$(gh api graphql -f query='query { viewer { projectsV2(first: 20) { nodes { id number } } } }' --jq ".data.viewer.projectsV2.nodes[] | select(.number == <PROJECT_NUMBER>) | .id")
STATUS_FIELD_ID=$(gh project field-list <PROJECT_NUMBER> --owner @me --format json --jq '.fields[] | select(.name == "Status") | .id')
TODO_OPTION_ID=$(gh api graphql -f query="query { node(id: \"$STATUS_FIELD_ID\") { ... on ProjectV2SingleSelectField { options { id name } } } }" --jq '.data.node.options[] | select(.name == "Todo") | .id')
```
2. For each item on the board:
```bash
ITEM_ID=$(gh project item-list <PROJECT_NUMBER> --owner @me --format json --jq ".items[] | select(.content.number == <ISSUE_NUMBER>) | .id")
gh project item-edit --project-id "$PROJECT_NODE_ID" --id "$ITEM_ID" --field-id "$STATUS_FIELD_ID" --single-select-option-id "$TODO_OPTION_ID"
```

### 3g. Link Project to Repository

GitHub Projects v2 are owned by users/orgs, not repos. By default, the board only appears under the user's profile. Link it to the repo so it also appears on the repo's "Projects" tab:

```bash
REPO_OWNER=$(gh repo view --json owner -q '.owner.login')
REPO_NAME=$(gh repo view --json name -q '.name')
REPO_NODE_ID=$(gh api graphql -f query="query { repository(owner: \"$REPO_OWNER\", name: \"$REPO_NAME\") { id } }" --jq '.data.repository.id')
gh api graphql -f query="mutation { linkProjectV2ToRepository(input: { projectId: \"$PROJECT_NODE_ID\", repositoryId: \"$REPO_NODE_ID\" }) { repository { id } } }" --silent
```

This is idempotent — linking an already-linked project is a no-op.

### 3h. Second Pass — Inject Dependencies
After all issues are created, update "Depends On" sections with actual issue numbers:
```bash
gh issue edit <NUMBER> --body "<updated body with real #N references>"
```

---

## Phase 4: Summary

Update `PLAN.md` with:
- Issue numbers next to each task
- Dependency graph with real issue references
- Milestone links

Commit and push:
```bash
git add PLAN.md
git commit -m "docs: add project plan with GitHub issues"
git push
```

Output a summary table:
```
| # | Title | Labels | Milestone | Depends On |
|---|-------|--------|-----------|------------|
```

After the table, suggest starting with the first issue. Use plain language:
> Start with issue #N — create branch `feature/branch-name` and begin coding.

**Do NOT reference specific skill names or plugin syntax** (e.g., `/feature-dev`, `feature-dev:feature-dev`). The user knows how to start working. Just tell them which issue is next and the branch name.

---

## Rules

- Create 5-15 issues (granular but not overwhelming)
- Always start with a `phase:infra` setup task
- Label every issue with `phase:*` AND `priority:*`
- P0 = must have for MVP, P1 = important, P2 = nice to have
- Every issue gets a branch name in the body
- Use conventional commit prefixes in titles: `feat:`, `fix:`, `docs:`, `chore:`
- Never create issues without user approval of the plan first
- **Always include an orchestration job issue** — the LAST milestone must contain a `chore: create orchestration job` issue that chains all tasks with `depends_on`. Deploy = Run. The user should never need to manually trigger individual pipelines or scripts.
- Every issue that produces a runnable artifact (pipeline, script, notebook) MUST specify its `Execution` trigger in the issue body
