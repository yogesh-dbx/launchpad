# Databricks AI Dev Kit — Launchpad

The launchpad layer sits on top of the [Databricks AI Dev Kit](https://github.com/databricks-solutions/ai-dev-kit) and adds opinionated project automation, slash commands, hooks, and templates tuned for Claude Code + Databricks workflows.

**AI Dev Kit** gives you MCP tools and skills.
**Launchpad** gives you the workflow: project creation, planning, shipping, context management, and guardrails.

## Prerequisites

| Tool | Install |
|------|---------|
| Node.js / npm | [https://nodejs.org/](https://nodejs.org/) (required to install Claude Code) |
| Claude Code | `npm install -g @anthropic-ai/claude-code` |
| Databricks CLI | [https://docs.databricks.com/dev-tools/cli/install.html](https://docs.databricks.com/dev-tools/cli/install.html) |
| GitHub CLI | [https://cli.github.com/](https://cli.github.com/) (optional, required for `/plan` and `/ship`) |
| python3 | [https://www.python.org/downloads/](https://www.python.org/downloads/) (required for project scripts) |
| jq | [https://jqlang.github.io/jq/download/](https://jqlang.github.io/jq/download/) (required for statusline and hooks) |
| AI Dev Kit | `bash <(curl -sL https://raw.githubusercontent.com/databricks-solutions/ai-dev-kit/main/install.sh)` |
| uv | `curl -LsSf https://astral.sh/uv/install.sh \| sh` (recommended) |

## Installation

```bash
git clone https://github.com/yogesh-singh_data/launchpad.git
cd launchpad
bash install-launchpad.sh
```

> **Note:** This repo is currently private. Request access from the repo owner or fork it to your own account.

On first run, the installer prompts for your name, role, and projects directory. These are saved to `~/.config/aidevkit/config` so subsequent runs are non-interactive.

The installer is idempotent. Run it again after pulling updates to refresh all installed files.

## What Gets Installed

```
~/.claude/
  CLAUDE.md                    # Global instructions (personalized with your name/role)
  settings.json                # Permissions, hooks, statusline (created once, never overwritten)
  commands/
    pause-work.md              # /pause-work — save context before stepping away
    resume-work.md             # /resume-work — restore context
    stats.md                   # /stats — session statistics
  agents/
    databricks-executor.md     # Subagent for Databricks execution tasks
  hooks/
    context-monitor.sh         # Warns when context window is running low
    inject-open-issues.sh      # Injects open GitHub issues (available, not wired by default)
    claude-todo-hook           # Tracks TODOs and GitHub issues across sessions
  statusline.sh                # Status bar: model, branch, cost, context usage

~/.local/bin/
  newproject                   # Create a new project with full launchpad
  openproject                  # Open an existing project (interactive picker or by name)
  gh-project-init              # Set up GitHub Projects v2 board
  updateaidevkit               # Pull latest AI Dev Kit + refresh all projects
  dbx-workspace-info           # Print Databricks workspace details
  dbx-profile                  # Manage Databricks CLI profiles (show, list, use, add, test)

~/.local/share/project-templates/
  CLAUDE.md                    # Project-level Claude instructions template
  settings.json                # Project-level settings template
  commands/                    # /plan, /ship, /demo-prep, /techdebt, /customer-review, ...
  agents/                      # dbx-validator, security-reviewer
  databricks/                  # databricks.yml bundle template
  github/                      # Issue templates, PR template, CI workflow
  scripts/                     # Infrastructure setup scripts
```

## Usage

### Create a New Project

```bash
# Full setup with profile and catalog
newproject my-pipeline --profile my-workspace --catalog analytics

# Minimal — uses DEFAULT profile, prompts for catalog
newproject my-pipeline

# Skip GitHub, don't auto-open Claude
newproject quick-test --catalog analytics --no-github --no-open
```

This creates `~/dev/my-pipeline`, verifies Databricks auth (runs `databricks auth login` if needed), installs the AI Dev Kit, stamps project config with your profile and catalog, and opens Claude Code.

### Daily Workflow

1. **Open your project:** `openproject my-project` (or interactive: `openproject`)
2. **Plan work:** `/plan Build a streaming pipeline that ingests Kafka events`
3. **Work on issues:** Claude picks up the next issue, writes code, tests it
4. **Ship:** `/ship Add sessionization to cleansed layer` — tests, commits, pushes, creates PR, validates on Databricks, closes the issue
5. **Pause:** `/pause-work` saves full context; `/resume-work` restores it next session

## Available Commands

### Global Commands (available in every project)

| Command | Purpose |
|---------|---------|
| `/pause-work` | Serialize session context to disk before stepping away |
| `/resume-work` | Restore context from a previous `/pause-work` |
| `/stats` | Show session stats: tokens used, cost, context usage |

### Project Commands (installed per-project via templates)

| Command | Purpose |
|---------|---------|
| `/plan <use case>` | Break a use case into a PLAN.md, GitHub issues, and a Projects v2 board |
| `/ship [title]` | Test, commit, push, create PR, execute on Databricks, validate, close issue |
| `/demo-prep [topic]` | Prepare code and talking points for a customer demo |
| `/techdebt [area]` | Analyze code for tech debt, suggest improvements |
| `/customer-review` | Review code quality and best practices before delivery |
| `/resume` | Resume work from a previous session's plan |

## The 7 Layers

The full toolkit is organized in layers, each building on the one below:

1. **AI Dev Kit** — Databricks MCP server, skills library, multi-IDE support. The foundation.
2. **Global Config** — `~/.claude/CLAUDE.md`, rules, permissions, hooks. Applies to every session.
3. **CLI Scripts** — `newproject`, `updateaidevkit`, `dbx-workspace-info`. Automate setup and maintenance.
4. **Project Templates** — `.claude/commands/`, `databricks.yml`, GitHub workflows. Stamped into each new project.
5. **Slash Commands** — `/plan`, `/ship`, `/demo-prep`. Encode repeatable workflows as single commands.
6. **Hooks and Agents** — Context monitor, issue injection, TODO tracking, Databricks executor subagent. Run automatically.
7. **Memory and Feedback** — `MEMORY.md` and feedback files. The system learns from your corrections.

## Customization

### User Config

Edit `~/.config/aidevkit/config` to change your name, role, or projects directory:

```bash
USER_NAME="Jane Doe"
USER_ROLE="Staff Data Engineer"
DEV_DIR="$HOME/projects"
```

Then re-run `bash install-launchpad.sh` to regenerate `~/.claude/CLAUDE.md`.

### Adding Rules

Drop `.md` files into `~/.claude/rules/`. Claude applies them based on the file type you are editing. Example: `databricks-python.md` activates when editing `.py` files in a Databricks project.

### Modifying Templates

Project templates live in `~/.local/share/project-templates/`. Edit them directly — `newproject` copies from this directory. Changes take effect on the next project you create.

To modify templates at the source (so `updateaidevkit` preserves your changes), edit the files in this repo under `templates/` and re-run the installer.

### Adding Commands

To add a global slash command, create a markdown file in `~/.claude/commands/`:

```bash
# ~/.claude/commands/my-command.md
Description of what the command does and instructions for Claude.
```

For project-specific commands, add them to `templates/commands/` and re-run the installer, or drop them directly into a project's `.claude/commands/` directory.

## Updating

To pull the latest AI Dev Kit skills and refresh all projects:

```bash
updateaidevkit
```

This updates the AI Dev Kit core, refreshes skills in every project under your dev directory, and regenerates the skill table in `~/.claude/CLAUDE.md`.

To update the launchpad itself (scripts, templates, hooks):

```bash
cd launchpad
git pull
bash install-launchpad.sh
```

## Uninstalling

To remove launchpad-installed files:

```bash
# Global config (selective — only remove launchpad-managed files)
rm -f ~/.claude/CLAUDE.md
rm -rf ~/.claude/rules ~/.claude/commands ~/.claude/agents ~/.claude/hooks
rm -f ~/.claude/statusline.sh

# Scripts
rm -f ~/.local/bin/{newproject,openproject,gh-project-init,updateaidevkit,dbx-workspace-info,dbx-profile,claude-todo-hook}

# Templates
rm -rf ~/.local/share/project-templates

# User config
rm -rf ~/.config/aidevkit
```

This does NOT remove the AI Dev Kit itself (`~/.ai-dev-kit/`), project-level configs, or `~/.claude/settings.json` (your customized permissions).

## Troubleshooting

**"AI Dev Kit not installed"** — Run the base installer first:
```bash
bash <(curl -sL https://raw.githubusercontent.com/databricks-solutions/ai-dev-kit/main/install.sh)
```

**"~/.local/bin is not on your PATH"** — Add to your shell profile (`~/.zshrc` or `~/.bashrc`):
```bash
export PATH="$HOME/.local/bin:$PATH"
```

**Commands not recognized in Claude** — Make sure the project has `.claude/commands/` populated. Run `newproject` or manually copy from `~/.local/share/project-templates/commands/`.

**Settings overwritten** — The installer never overwrites `~/.claude/settings.json` if it already exists. To reset it, delete the file and re-run the installer.
