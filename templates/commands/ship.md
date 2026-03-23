---
allowed-tools: Bash(git:*), Bash(gh pr:*), Bash(gh issue:*), Bash(gh project:*), Bash(gh api:*), Bash(uv run:*), Bash(pytest:*), Bash(ruff:*), mcp__databricks__*, Agent
description: "Test, commit, push, create a PR, execute on Databricks, validate, and close the issue"
argument-hint: "[--sdd] [PR title]"
---

# /ship — Test → Commit → Push → PR

You are a shipping agent. You take the current changes, run quality checks, commit, push, and open a pull request.

### ⛔ FORBIDDEN:
- **Do NOT use the Skill tool** to invoke this command. `/ship` is a command file, not a skill.
- **Do NOT pass `query_tags` to `mcp__databricks__execute_sql`** — it causes a crash. Omit it.
- In standard mode (no `--sdd`): **Do NOT use the Agent tool.** Run all steps sequentially.

---

## Step 0: Parse Mode

Check `$ARGUMENTS` for the `--sdd` flag:
- If `$ARGUMENTS` contains `--sdd` → **SDD mode** (run review pipeline before shipping)
- Otherwise → **Standard mode** (skip to Step 1)

Strip `--sdd` from arguments — any remaining text is the PR title.

### SDD Mode — Review Pipeline (before Step 1)

When `--sdd` is active, run three subagents in sequence before the standard ship steps. Each runs in a **fresh context** via the Agent tool.

**Important:** The Agent tool uses `subagent_type` parameter. Use the agent definitions in `.claude/agents/`.

#### SDD-1: Implementer Review

The code is already written (you're shipping it). Skip the implementer — go straight to reviewers.

#### SDD-2: Spec Compliance Review

Dispatch the `sdd-spec-reviewer` agent:
```
Prompt: "Review the implementation for issue #N against its spec.
Issue body: <paste the issue body from gh issue view>
Changed files: <git diff main...HEAD --name-only>
Git diff: <git diff main...HEAD>
Report: APPROVED or ISSUES_FOUND with a requirement checklist."
```

Use: `Agent(subagent_type="general-purpose", prompt=<above>)`

**If ISSUES_FOUND with critical gaps:** Show the user the findings and ask: "Spec review found issues. Fix and re-run, or ship anyway?"

#### SDD-3: Quality Review

Dispatch the `sdd-quality-reviewer` agent:
```
Prompt: "Review code quality and Databricks best practices.
Changed files: <git diff main...HEAD --name-only>
Git diff: <git diff main...HEAD>
Report: APPROVED or ISSUES_FOUND with severity table."
```

Use: `Agent(subagent_type="general-purpose", prompt=<above>)`

**If ISSUES_FOUND with Critical severity:** Show the user and ask: "Quality review found critical issues. Fix and re-run, or ship anyway?"

#### SDD Summary

After both reviewers complete, show:
```
SDD Review:
  Spec:    ✅ APPROVED (or ❌ ISSUES_FOUND — N gaps)
  Quality: ✅ APPROVED (or ❌ ISSUES_FOUND — N critical)
```

If both APPROVED → proceed to Step 1 (standard ship).
If either has issues → stop and wait for user decision.

---

## Context (auto-gathered)

Read these before starting:
```
!git status
!git diff HEAD
!git branch --show-current
!git log --oneline -5
```

Also read `.claude/CLAUDE.md` for project conventions.

---

## Step 1: Pre-flight

1. **Check for changes**: Run `git status`. If no changes exist, tell the user and stop.
2. **Check remote**: Run `git remote -v`. If no remote exists, warn the user.
3. **Branch check**: If on `main`, create a feature branch:
   ```bash
   git checkout -b feature/<short-description>
   ```
   Never commit directly to main.
4. **Detect linked issue**: Look at the branch name and recent work to find a related GitHub issue number. Check with:
   ```bash
   gh issue list --state open --limit 20
   ```

---

## Step 2: Test + Lint

Run quality checks if the tools exist:

```bash
# Lint (if ruff is available)
if command -v ruff &>/dev/null; then
  ruff check .
fi

# Tests (if pytest is available and tests/ exists)
if [ -d tests ] && command -v pytest &>/dev/null; then
  pytest tests/ -x -q
fi
```

If tests or lint fail:
- Show the errors to the user
- Ask: "Tests/lint failed. Fix and retry, or ship anyway?"
- Do NOT proceed without explicit user approval

---

## Step 3: Commit + Push

1. **Stage changes**:
   ```bash
   git add -A
   ```

2. **Craft commit message** using conventional commits:
   - `feat:` — new feature
   - `fix:` — bug fix
   - `docs:` — documentation
   - `refactor:` — code improvement
   - `chore:` — maintenance
   - `test:` — tests

   If a related issue was found, reference it: `feat: add SDP pipeline (#3)`

3. **Commit**:
   ```bash
   git commit -m "<message>"
   ```

4. **Push**:
   ```bash
   git push -u origin $(git branch --show-current)
   ```

---

## Step 4: Create PR

Check if a PR already exists for this branch:
```bash
gh pr list --head $(git branch --show-current) --state open
```

If no PR exists, create one:
```bash
gh pr create \
  --title "<PR title>" \
  --body "$(cat <<'EOF'
## Summary

- <bullet points>

## Changes

- <key changes>

## Test Plan

- [ ] Tests pass locally (`pytest`)
- [ ] Linting passes (`ruff check`)
- [ ] Manually verified expected behavior

## Related Issues

Refs #<N>
EOF
)"
```

**Do NOT add "Generated with Claude Code" or any AI attribution to the PR body.**

If `$ARGUMENTS` was provided, use it as the PR title. Otherwise, derive from the commit message.

If a PR already exists, just push (the PR auto-updates).

---

## Step 5: Update Project Board

First, pull latest and find the project number (may have been pushed from another session):
```bash
git pull --quiet 2>/dev/null || true
```

Read the project number:
```bash
cat .github/.project-number
```

If the file doesn't exist, try the API fallback:
```bash
REPO_NAME=$(basename $(git remote get-url origin) .git)
gh api graphql -f query='query { viewer { projectsV2(first: 20) { nodes { number title } } } }' --jq ".data.viewer.projectsV2.nodes[] | select(.title == \"$REPO_NAME\") | .number"
```

If a project number is found, add the PR's linked issue to the board and update its status:
```bash
PROJECT_NUM=<number>
ISSUE_URL="https://github.com/<owner>/<repo>/issues/<N>"
gh project item-add $PROJECT_NUM --owner @me --url "$ISSUE_URL"
```

This step is best-effort — don't fail the ship if it doesn't work.

---

## Step 6: Summary

Output a clean summary:
```
Branch:  feature/add-pipeline
Commit:  abc1234 feat: add SDP pipeline (#3)
PR:      https://github.com/<owner>/<repo>/pull/N
Tests:   ✅ passed (or ⏭️ skipped)
Lint:    ✅ passed (or ⏭️ skipped)
Board:   📋 Updated to "In Progress" (or ⏭️ skipped)
```

---

## Step 7: Execute, Validate & Close Issue

**This step is what makes "ship" mean DONE, not just "code pushed."**

1. **Find the linked issue**: Use the issue number from Step 1 (detected from branch name or commit).

2. **Read the issue's Validation section**: Fetch the issue body and find the `## Validation` section:
   ```bash
   gh issue view <N> --json body --jq '.body'
   ```
   Parse the **Run**, **Verify**, and **Teardown** blocks.

3. **Execute (Run block)**:
   - For Python scripts: upload to workspace with `mcp__databricks__upload_file`, then create a one-time serverless job with `mcp__databricks__manage_jobs` (action: create), run with `mcp__databricks__manage_job_runs` (action: run_now), and wait with `mcp__databricks__manage_job_runs` (action: wait).
   - For SDP pipelines: use `mcp__databricks__start_update` then `mcp__databricks__get_update` to poll.
   - For SQL: use `mcp__databricks__execute_sql`.
   - For dashboards/Genie: use the appropriate `mcp__databricks__create_or_update_*` tool.

   **ALWAYS show the user a monitoring link** so they can watch execution in real time:
   - **Jobs**: After `run_now`, the response includes `run_id`. Show: `🔗 Monitor: https://<host>/jobs/<job_id>/runs/<run_id>`  (or use `run_page_url` from the `wait` response)
   - **Pipelines**: After `start_update`, show: `🔗 Monitor: https://<host>/pipelines/<pipeline_id>/updates/<update_id>`
   - **Dashboards**: After create, show the dashboard URL returned by the tool
   - **Genie**: After create, show the Genie space URL

   If execution **fails**: show the error AND the monitoring link, do NOT close the issue. Tell the user what went wrong and stop.

4. **Validate (Verify block)**: Run the verification queries/checks from the Validation section. Compare results against expected output. If validation **fails**: show what was expected vs actual, do NOT close the issue.

5. **Teardown**: Run any cleanup steps (e.g., delete one-time job).

6. **Close the issue** with a validation summary comment:
   ```bash
   gh issue close <N> --comment "## Execution Validated ✅

   <summary of what ran, what was verified, key metrics>"
   ```

7. **Update project board status** to "Done" if the board is available:
   ```bash
   # Get "Done" option ID and update the item
   DONE_OPTION_ID=$(gh api graphql ... --jq '... select(.name == "Done") ...')
   gh project item-edit --project-id "$PROJECT_NODE_ID" --id "$ITEM_ID" --field-id "$STATUS_FIELD_ID" --single-select-option-id "$DONE_OPTION_ID"
   ```

**If no Validation section exists in the issue**: warn the user that the issue has no validation steps. Ask whether to close anyway or leave open.

---

## Step 8: Merge to Main

**Ask the user before merging:**

> Issue #N closed. PR #M ready to merge.
> Merge PR #M to main? [Y/n]

**If user confirms (or says nothing — default yes):**
```bash
gh pr merge <N> --squash --delete-branch
git checkout main
git pull --quiet
```

**If user says no:** Leave the PR open. Tell the user they can merge later with `gh pr merge <N> --squash --delete-branch`.

---

## Step 9: Final Summary

Update the summary from Step 6 to include execution and merge status:
```
SDD:       ✅ Spec APPROVED, Quality APPROVED (or ⏭️ standard mode)
Branch:    feature/add-pipeline
Commit:    abc1234 feat: add SDP pipeline (#3)
PR:        https://github.com/<owner>/<repo>/pull/N
Tests:     ✅ passed
Lint:      ✅ passed
Board:     📋 Updated to "Done"
Execution: ✅ Serverless job completed in 55s
  🔗 https://<host>/jobs/<job_id>/runs/<run_id>
Validated: ✅ Table has 90,917 rows, 1,000 players
Issue:     ✅ #3 closed with validation comment
Merged:    ✅ PR #M squash-merged to main (or ⏭️ skipped)
```

---

## Rules

- **Never force push**
- **Never commit to main directly** — always use a feature branch
- **Always create a PR** — no direct pushes to main
- **Reference issue numbers** in commits when applicable
- **Stop on test/lint failure** — ask user before proceeding
- **Use conventional commits** — `feat:`, `fix:`, `docs:`, etc.
- **Never use `Closes #N` in PR body** — always use `Refs #N`. Issues should only be closed AFTER execution is validated (job ran successfully, output verified), not when code is merged. Merging code ≠ done.
