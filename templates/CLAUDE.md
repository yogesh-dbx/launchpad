# Project: PROJECT_NAME

## Session Contract

Before doing ANY work in this project, read this entire file. If this is the start of a session, confirm you understand by stating:
1. The catalog and schemas you'll use
2. The compute type (serverless)
3. The branch strategy (never commit to main)

Do not write code until you have confirmed these three things.

---

## Environment

- **Databricks Profile:** `DATABRICKS_PROFILE`
- **Catalog:** `PROJECT_CATALOG`
- **Schemas:** `PROJECT_CATALOG.raw` (bronze), `PROJECT_CATALOG.cleansed` (silver), `PROJECT_CATALOG.curated` (gold)
- **Warehouse:** Serverless Starter Warehouse (via DAB variable lookup)
- **Python:** managed by `uv`

---

## Databricks Conventions

### Serverless First
Always use serverless compute. Never hardcode cluster IDs. Use `warehouse_id` variable lookup in `databricks.yml`.

### Unity Catalog
Always use three-level namespace: `catalog.schema.table`. Never reference `hive_metastore`. Parameterize catalog and schema names — never hardcode them.

### Medallion Architecture
- **raw** (bronze) — source data as-is, append-only
- **cleansed** (silver) — cleaned, deduplicated, typed
- **curated** (gold) — business-level aggregations, features, metrics

### Secrets
Never hardcode tokens, passwords, or API keys. Use `dbutils.secrets.get(scope, key)` or Databricks secret scopes.

### Deployment
Use Databricks Asset Bundles (DABs): `databricks bundle deploy --target dev`. CI/CD auto-deploys on push to `main` via GitHub Actions.

---

## Skills

Prefer project-level skills in `.claude/skills/` over general knowledge for Databricks tasks. Check available skills before answering Databricks questions.

### Skill Invocation
When using the Skill tool, always use the **fully-qualified name** (`plugin:skill`):
- ✅ `feature-dev:feature-dev` — correct
- ❌ `feature-dev` — will fail with "Unknown skill"
- ✅ `commit-commands:commit` — correct
- ❌ `commit` — will fail

---

## Branch Strategy

- `main` — stable, always deployable. Never commit directly.
- `feature/*` — new features (e.g., `feature/add-streaming-pipeline`)
- `fix/*` — bug fixes
- `docs/*` — documentation only
- `chore/*` — repo maintenance

### Commits
Use conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`, `test:`
Reference issue numbers: `feat: add SDP pipeline (#3)`

---

## Commands

- `/plan <use case>` — break a use case into PLAN.md + GitHub issues + Projects v2 board
- `/ship [title]` — test → commit → push → PR in one command
- `/demo-prep [topic]` — prepare code for a customer demo
- `/techdebt [area]` — analyze code for tech debt and improvements
- `/customer-review` — review code quality before delivery

---

## Output Format

- **Pipeline files:** imports → config/parameters → transformations → write target (no business logic in notebooks)
- **Scripts:** docstring with purpose → main function → `if __name__ == "__main__"` guard
- **DAB resource YAML:** name → compute → depends_on → parameters (match existing `resources/` patterns)
- **Test files:** one test class per source module, at least one edge case per test function
- **SQL:** parameterized with variables, never string concatenation

---

## Build vs Ship — Two Separate Steps

**"Build" and "ship" are NEVER the same action.** When the user says "build issue #N", you:
1. Create the feature branch
2. Read the issue Contract
3. Write the code
4. Test locally (lint, syntax check)
5. **STOP and tell the user:** "Code ready. Run `/ship` or `/ship --sdd` when ready."

**Do NOT commit, push, create PRs, execute on Databricks, validate, or close issues during a build.** That is what `/ship` does — and the user must invoke it explicitly.

**NEVER manually `git commit` / `git push` / `gh pr create`.** The `/ship` command handles everything: test → commit → push → PR → execute on Databricks → validate output → merge to main → close the issue. Skipping `/ship` means the code is pushed but never actually run or validated — that is NOT done.

If a plugin (e.g., `feature-dev:feature-dev`) tries to commit/push on its own, **stop it** and tell the user to run `/ship`.

---

## Failure Conditions

Output is **unacceptable** if any of these are true:

- Code references `hive_metastore` instead of Unity Catalog three-level namespace
- SQL or Python contains hardcoded catalog or schema names instead of variables
- Any secret, token, or password appears in code (even as placeholder like `xxx` or `changeme`)
- A PR is created without a linked GitHub issue
- Commit messages don't follow conventional commits (`feat:`, `fix:`, `docs:`, etc.)
- Test files only test happy paths with no edge cases
- API signatures are used without checking official Databricks documentation

For Databricks-specific anti-patterns (e.g., `display()`, `collect()`, `checkpoint`, `spark.conf.set()`), refer to the relevant skills in `.claude/skills/`.

---

## Anti-Slop Rules

DO NOT generate:
- Verbose comments that restate the code (`# increment counter by 1`)
- Unnecessary abstractions or wrapper classes
- Over-engineered solutions for simple problems
- Placeholder/stub implementations without real logic
- Excessive logging that clutters output
- Type hints on obvious assignments (`x: int = 5`)

DO:
- Write concise, readable code
- Use descriptive variable names instead of comments
- Keep functions under 30 lines
- Prefer flat over nested
- Handle errors explicitly — no bare `except:` blocks
- Test edge cases, not happy paths

---

## Known Gotchas

For Databricks-specific gotchas (serverless jobs, SDP pipelines, DABs, Zerobus, MLflow), **always check the relevant skill in `.claude/skills/`** before writing code. Skills are the source of truth for SDK patterns, API quirks, and workarounds.

### MCP Tools
- **Never pass `query_tags` to `mcp__databricks__execute_sql`** — it causes `'str' object has no attribute 'as_dict'`. Omit the parameter entirely.
- **Never pass `output_format` as `"json"` unless you need machine-parseable output** — markdown (default) is smaller and works for validation.
- **Use MCP tools, not CLI, for Databricks operations** — `execute_sql`, `run_python_file_on_databricks`, `manage_jobs`, `start_update`, etc. The CLI flag syntax varies across versions.

---

## Before Writing Tests or New Code

1. **Read existing code first** — check `scripts/` for install scripts, `src/` for working patterns, `requirements.txt` / `pyproject.toml` for package names. Never guess package names or API signatures.
2. **Check skills** — run the relevant Databricks skill for the task (e.g., `databricks-jobs`, `databricks-spark-declarative-pipelines`, `databricks-asset-bundles`) to get current API patterns and known issues.
3. **Verify SDK versions** — use `inspect.signature(Class.__init__)` to confirm constructor args before writing code. SDK APIs change between major versions.
4. **Check environment constraints** — know whether code runs on serverless, cluster, or local. Not all pip packages are available on serverless compute.
5. **One failure = diagnose, two = switch approach** — if pip install fails on serverless, try local immediately. Don't retry the same failing approach 4 times.
