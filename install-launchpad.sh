#!/usr/bin/env bash
# install-launchpad.sh — Databricks AI Dev Kit Launchpad Installer
#
# Installs global Claude Code config, CLI scripts, and project templates
# on top of the base AI Dev Kit. Idempotent — safe to run multiple times.
#
# Usage:
#   bash install-launchpad.sh
#   bash <(curl -sL .../install-launchpad.sh)
set -euo pipefail

LAUNCHPAD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CONFIG_DIR="$HOME/.config/aidevkit"
CONFIG_FILE="$CONFIG_DIR/config"

# ── Colors (compatible with bash and zsh) ────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { printf "${BLUE}i${NC} %s\n" "$1"; }
success() { printf "${GREEN}✔${NC} %s\n" "$1"; }
warn()    { printf "${YELLOW}!${NC} %s\n" "$1"; }
error()   { printf "${RED}x${NC} %s\n" "$1" >&2; exit 1; }

# ── Helpers ──────────────────────────────────────────────────────────────────

# Escape a string for use as the replacement in sed s/pattern/replacement/
# Handles: \ & / newlines
sed_escape() {
  local s="$1"
  s="${s//\\/\\\\}"   # escape backslashes
  s="${s//&/\\&}"     # escape ampersands
  s="${s//\//\\/}"    # escape forward slashes
  printf '%s' "$s"
}

# Copy files from a source directory to a destination, creating it if needed.
# Usage: copy_dir_contents <src_dir> <dest_dir>
copy_dir_contents() {
  local src="$1" dest="$2"
  if [[ ! -d "$src" ]]; then
    warn "Source directory not found: $src — skipping"
    return 0
  fi
  mkdir -p "$dest"
  # Use find + cp to handle both files and nested subdirectories
  if command -v rsync &>/dev/null; then
    rsync -a "$src/" "$dest/"
  else
    cp -R "$src/"* "$dest/" 2>/dev/null || true
  fi
}

# ── Prerequisites ────────────────────────────────────────────────────────────

check_prerequisites() {
  local failed=0

  if ! command -v claude &>/dev/null; then
    warn "Claude Code not installed. Install: npm install -g @anthropic-ai/claude-code"
    (( failed++ ))
  fi

  if ! command -v databricks &>/dev/null; then
    warn "Databricks CLI not installed. Install: https://docs.databricks.com/dev-tools/cli/install.html"
    (( failed++ ))
  fi

  if ! command -v gh &>/dev/null; then
    warn "GitHub CLI not installed. Some features (newproject, /plan, /ship) require it."
  fi

  if ! command -v python3 &>/dev/null; then
    warn "python3 not installed. Required for project initialization."
    (( failed++ ))
  fi

  if ! command -v jq &>/dev/null; then
    warn "jq not installed. Required for statusline and hooks. Install: https://jqlang.github.io/jq/download/"
    (( failed++ ))
  fi

  if [[ ! -d "$HOME/.ai-dev-kit" ]]; then
    warn "AI Dev Kit not installed. Run: bash <(curl -sL https://raw.githubusercontent.com/databricks-solutions/ai-dev-kit/main/install.sh)"
    (( failed++ ))
  fi

  # Verify launchpad source files exist
  if [[ ! -d "$LAUNCHPAD_DIR/global" ]]; then
    warn "Launchpad source files not found. Expected directory: $LAUNCHPAD_DIR/global"
    (( failed++ ))
  fi

  if (( failed > 0 )); then
    error "Missing $failed prerequisite(s). Install them and re-run."
  fi

  success "Prerequisites check passed"
}

# ── User Config ──────────────────────────────────────────────────────────────

load_or_prompt_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    info "Using saved config from $CONFIG_FILE"
    info "  Name:    $USER_NAME"
    info "  Role:    $USER_ROLE"
    info "  Dev dir: $DEV_DIR"
    return 0
  fi

  echo ""
  printf "${BOLD}First-time setup${NC} — let's configure your environment.\n"
  echo ""

  local default_name
  default_name="$(git config --global user.name 2>/dev/null || echo "Developer")"

  read -rp "Your name [$default_name]: " USER_NAME
  USER_NAME="${USER_NAME:-$default_name}"

  read -rp "Your role [Databricks Developer]: " USER_ROLE
  USER_ROLE="${USER_ROLE:-Databricks Developer}"

  read -rp "Projects directory [$HOME/dev]: " DEV_DIR
  DEV_DIR="${DEV_DIR:-$HOME/dev}"

  # Persist config (escape double quotes in values)
  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG_FILE" <<EOF
USER_NAME="${USER_NAME//\"/\\\"}"
USER_ROLE="${USER_ROLE//\"/\\\"}"
DEV_DIR="${DEV_DIR//\"/\\\"}"
EOF
  success "Config saved to $CONFIG_FILE"
}

# ── Install Global Claude Config ─────────────────────────────────────────────

install_global() {
  info "Installing global Claude config to ~/.claude/ ..."

  mkdir -p "$HOME/.claude"/{rules,commands,agents,hooks}

  # ── CLAUDE.md from template ──────────────────────────────────────────────
  local template="$LAUNCHPAD_DIR/global/CLAUDE.md.template"
  if [[ -f "$template" ]]; then
    local escaped_name escaped_role
    escaped_name="$(sed_escape "$USER_NAME")"
    escaped_role="$(sed_escape "$USER_ROLE")"

    sed -e "s/{{USER_NAME}}/$escaped_name/g" \
        -e "s/{{USER_ROLE}}/$escaped_role/g" \
        "$template" > "$HOME/.claude/CLAUDE.md"
    success "CLAUDE.md installed (personalized)"
  else
    warn "CLAUDE.md.template not found — skipping"
  fi

  # ── settings.json (never overwrite user customizations) ──────────────────
  local settings_template="$LAUNCHPAD_DIR/global/settings.json.template"
  if [[ ! -f "$HOME/.claude/settings.json" ]]; then
    if [[ -f "$settings_template" ]]; then
      cp "$settings_template" "$HOME/.claude/settings.json"
      success "settings.json installed"
    else
      warn "settings.json.template not found — skipping"
    fi
  else
    info "settings.json already exists — preserved (won't overwrite your customizations)"
  fi

  # ── Commands ─────────────────────────────────────────────────────────────
  if [[ -d "$LAUNCHPAD_DIR/global/commands" ]]; then
    copy_dir_contents "$LAUNCHPAD_DIR/global/commands" "$HOME/.claude/commands"
    success "Commands installed"
  fi

  # ── Agents ───────────────────────────────────────────────────────────────
  if [[ -d "$LAUNCHPAD_DIR/global/agents" ]]; then
    copy_dir_contents "$LAUNCHPAD_DIR/global/agents" "$HOME/.claude/agents"
    success "Agents installed"
  fi

  # ── Hooks (must be executable) ───────────────────────────────────────────
  if [[ -d "$LAUNCHPAD_DIR/global/hooks" ]]; then
    copy_dir_contents "$LAUNCHPAD_DIR/global/hooks" "$HOME/.claude/hooks"
    find "$HOME/.claude/hooks" -type f -exec chmod +x {} +
    success "Hooks installed"
    # claude-todo-hook must also be on PATH (referenced by project settings.local.json hooks)
    if [[ -f "$HOME/.claude/hooks/claude-todo-hook" ]]; then
      mkdir -p "$HOME/.local/bin"
      cp "$HOME/.claude/hooks/claude-todo-hook" "$HOME/.local/bin/claude-todo-hook"
      chmod +x "$HOME/.local/bin/claude-todo-hook"
    fi
  fi

  # ── Statusline ───────────────────────────────────────────────────────────
  if [[ -f "$LAUNCHPAD_DIR/global/statusline.sh" ]]; then
    cp "$LAUNCHPAD_DIR/global/statusline.sh" "$HOME/.claude/statusline.sh"
    chmod +x "$HOME/.claude/statusline.sh"
    success "Statusline installed"
  fi

  success "Global config installed to ~/.claude/"
}

# ── Install Scripts ──────────────────────────────────────────────────────────

install_scripts() {
  info "Installing scripts to ~/.local/bin/ ..."

  local bin_dir="$HOME/.local/bin"
  mkdir -p "$bin_dir"

  local scripts=(newproject openproject gh-project-init updateaidevkit dbx-workspace-info dbx-profile)
  local installed=0

  for script in "${scripts[@]}"; do
    local src="$LAUNCHPAD_DIR/scripts/$script"
    if [[ -f "$src" ]]; then
      cp "$src" "$bin_dir/$script"
      chmod +x "$bin_dir/$script"
      (( installed++ ))
    else
      warn "Script not found: $src — skipping"
    fi
  done

  # Check if ~/.local/bin is on PATH
  if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
    echo ""
    warn "~/.local/bin is not on your PATH. Add to your shell profile:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
  fi

  success "Scripts installed ($installed commands)"
}

# ── Install Project Templates ────────────────────────────────────────────────

install_templates() {
  info "Installing project templates to ~/.local/share/project-templates/ ..."

  local tmpl_dir="$HOME/.local/share/project-templates"
  local src_dir="$LAUNCHPAD_DIR/templates"

  if [[ ! -d "$src_dir" ]]; then
    warn "Templates source directory not found: $src_dir — skipping"
    return 0
  fi

  # Replace with fresh copy
  rm -rf "$tmpl_dir"
  mkdir -p "$(dirname "$tmpl_dir")"
  cp -R "$src_dir" "$tmpl_dir"

  success "Templates installed to $tmpl_dir"
}

# ── Summary ──────────────────────────────────────────────────────────────────

print_summary() {
  echo ""
  echo "What was installed:"
  echo "  ~/.claude/CLAUDE.md              Global AI assistant instructions"
  echo "  ~/.claude/settings.json          Permissions, hooks, statusline config"
  echo "  ~/.claude/commands/              /pause-work, /resume-work, /stats"
  echo "  ~/.claude/agents/                Databricks executor subagent"
  echo "  ~/.claude/hooks/                 Context monitor, issue injection, TODO tracking"
  echo "  ~/.claude/statusline.sh          Status bar (model, branch, cost, context)"
  echo "  ~/.local/bin/                    newproject, openproject, gh-project-init, updateaidevkit, dbx-workspace-info, dbx-profile"
  echo "  ~/.local/share/project-templates/  Project templates"
  echo ""
  echo "Next steps:"
  echo "  1. Create a project:    newproject my-pipeline"
  echo "  2. Open an existing one: openproject my-project"
  echo "  3. Update later:        updateaidevkit"
  echo ""
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
  echo ""
  printf "${BOLD}"
  echo "=================================================="
  echo "  Databricks AI Dev Kit — Launchpad Installer"
  echo "=================================================="
  printf "${NC}"
  echo ""

  check_prerequisites
  load_or_prompt_config

  echo ""
  install_global
  echo ""
  install_scripts
  echo ""
  install_templates

  echo ""
  echo "=================================================="
  success "Launchpad installed successfully!"
  print_summary
}

main "$@"
