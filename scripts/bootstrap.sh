#!/usr/bin/env bash
# bootstrap.sh — the workshop-day installer for a Personal Agentic OS.
#
# Installs the full foundation stack (Homebrew, Node.js, Git, GitHub CLI,
# VS Code, Claude Code) and the capture stack (Granola, Wispr Flow), pauses
# cleanly at the browser logins, asks exactly
# one question (your workspace name), creates your private workspace from the
# template, turns on hourly sync, prints a report card, and hands off to the
# harness.
#
# Idempotent: every step checks before it acts. Running it twice is harmless;
# running it on a half-set-up machine finishes the job.
#
# It orchestrates only official installers (Homebrew's install script and
# Homebrew-reviewed casks). It fetches no binaries itself.
#
# Usage:
#   bash bootstrap.sh                     # the normal path
#   bash bootstrap.sh --dry-run           # print what would happen, change nothing
#   bash bootstrap.sh --workspace-name my-paos   # skip the one question
#   bash bootstrap.sh --no-launch         # skip the final harness launch
#
# Executable form of:
#   https://supersuit.wiki/paos/supersuit-up-workshop/install-your-tools
#   https://supersuit.wiki/paos/supersuit-up-workshop/set-up-your-workspace

set -uo pipefail

# The CLIENT repo. PAOS ships from here: the workspace template, the plugin
# marketplace, the upgrade ledger and the issue tracker are all this one repo, and
# read access to it is what makes someone a client.
#
# It moved here in v1.22.0, and this installer was NOT updated at the time. For a
# stretch, the publicly advertised one-command install pointed at the development
# repo, which a client cannot read: the upgrade path was migrated and the INSTALL
# path was not. If you move distribution again, grep for the old name everywhere
# before you consider it done.
TEMPLATE_REPO="${PAOS_CLIENT_REPO:-SupersuitUp/paos}"

# Where PAOS used to ship. Only used to RECOGNISE a workspace created before the
# move, so an existing operator is not told they have no workspace.
LEGACY_REPO="SupersuitUp/personal-agentic-os-workspace-template"
PROJECTS_DIR="$HOME/Documents/github-repos"
APPS_DIR="${PAOS_APPS_DIR:-/Applications}"   # overridable so tests can exercise the cold path
LOG_FILE="$HOME/.paos-setup.log"

DRY_RUN=0
NO_LAUNCH=0
WORKSPACE_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --no-launch) NO_LAUNCH=1 ;;
    --workspace-name) WORKSPACE_NAME="${2:-}"; shift ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//' | head -30
      exit 0
      ;;
    *) echo "Unknown option: $1 (try --help)"; exit 1 ;;
  esac
  shift
done

# ---------- Logging and failure handling ----------

CURRENT_STEP="starting"
STEP_START=0

log_line() {
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" >> "$LOG_FILE"
}

step_begin() {
  CURRENT_STEP="$1"
  STEP_START=$(date +%s)
  echo ""
  echo "==> $1"
  log_line "BEGIN $1"
}

step_done() {
  local elapsed=$(($(date +%s) - STEP_START))
  log_line "OK    $CURRENT_STEP (${elapsed}s)"
}

on_fail() {
  log_line "FAIL  $CURRENT_STEP"
  echo ""
  echo "=================================================="
  echo "  Setup hit a problem during: $CURRENT_STEP"
  echo ""
  echo "  This is normal and fixable. Copy the last twenty"
  echo "  lines of output above (and the log at $LOG_FILE)"
  echo "  and paste them into your AI chat (Claude, ChatGPT,"
  echo "  Gemini) with the question: \"I was running the PAOS"
  echo "  bootstrap script and got this. What do I do?\""
  echo ""
  echo "  Then run this script again. It picks up where it"
  echo "  left off; finished steps are skipped."
  echo "=================================================="
  exit 1
}

run() { # run <command...> — executes, or narrates under --dry-run
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "    [dry-run] would run: $*"
    return 0
  fi
  "$@" || on_fail
}

# ---------- Platform gate ----------

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This bootstrap currently supports macOS only."
  echo "On Windows or Linux, follow the manual steps at:"
  echo "  https://supersuit.wiki/paos/supersuit-up-workshop/install-your-tools"
  exit 1
fi

OS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo 0)"
if [[ "${OS_VERSION%%.*}" -lt 13 ]]; then
  echo "macOS $OS_VERSION is below the macOS 13 floor for these tools."
  echo "Run Software Update first (System Settings > General > Software Update),"
  echo "then run this script again."
  exit 1
fi

echo "=================================================="
echo "  PAOS BOOTSTRAP"
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "  DRY RUN: nothing will be installed or changed."
fi
echo "  Log: $LOG_FILE"
echo "=================================================="
log_line "=== bootstrap run started (dry_run=$DRY_RUN) ==="

# ---------- Step 1: Homebrew ----------

step_begin "Homebrew (the Mac package manager)"
BREW_BIN=""
if command -v brew >/dev/null 2>&1; then
  BREW_BIN="$(command -v brew)"
  echo "    already installed: $(brew --version | head -1)"
elif [[ -x /opt/homebrew/bin/brew ]]; then
  BREW_BIN="/opt/homebrew/bin/brew"
  echo "    installed but not on PATH — repairing"
elif [[ -x /usr/local/bin/brew ]]; then
  BREW_BIN="/usr/local/bin/brew"
  echo "    installed but not on PATH — repairing"
else
  echo "    not found — installing via the official Homebrew installer."
  echo "    You may be asked for your Mac login password. Your typing is"
  echo "    invisible while you type it. That is normal."
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "    [dry-run] would run the official Homebrew install script"
  else
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || on_fail
    if [[ -x /opt/homebrew/bin/brew ]]; then BREW_BIN="/opt/homebrew/bin/brew"; else BREW_BIN="/usr/local/bin/brew"; fi
  fi
fi

# Put brew on PATH for this shell and every future one.
if [[ -n "$BREW_BIN" && "$DRY_RUN" -eq 0 ]]; then
  eval "$("$BREW_BIN" shellenv)"
  ZPROFILE="$HOME/.zprofile"
  if ! grep -qs 'brew shellenv' "$ZPROFILE"; then
    echo "eval \"\$($BREW_BIN shellenv)\"" >> "$ZPROFILE"
    echo "    added Homebrew to PATH in ~/.zprofile"
  fi
fi
step_done

# ---------- Step 2: Foundation tools ----------

step_begin "Foundation tools (Node.js, Git, GitHub CLI)"
for formula in node git gh; do
  if command -v "$formula" >/dev/null 2>&1; then
    echo "    $formula already installed: $("$formula" --version 2>/dev/null | head -1)"
  else
    echo "    installing $formula..."
    run brew install "$formula"
  fi
done
step_done

# ---------- Step 3: VS Code ----------

step_begin "VS Code (your window into the file system)"
if [[ -d "$APPS_DIR/Visual Studio Code.app" ]] || command -v code >/dev/null 2>&1; then
  echo "    already installed"
else
  echo "    installing..."
  run brew install --cask visual-studio-code
fi
step_done

# ---------- Step 4: Claude Code ----------

step_begin "Claude Code (the agentic harness)"
if command -v claude >/dev/null 2>&1; then
  echo "    already installed: $(claude --version 2>/dev/null | head -1)"
else
  echo "    installing via Homebrew cask (reviewed, signed binary)..."
  run brew install --cask claude-code
fi
step_done

# ---------- Step 5: Capture stack (Granola + Wispr Flow) ----------
# Both are Homebrew-reviewed casks, so the *install* is mechanical and belongs
# to the script. What stays human is the sign-in and the subscription, which
# the report card lists. Granola is not optional: the workspace ships a
# sync-granola skill that talks to the Granola desktop app.

step_begin "Capture stack (Granola for meetings, Wispr Flow for voice)"
if [[ -d "$APPS_DIR/Granola.app" ]]; then
  echo "    Granola already installed"
else
  echo "    installing Granola (meeting transcription)..."
  run brew install --cask granola
fi
if [[ -d "$APPS_DIR/Wispr Flow.app" ]]; then
  echo "    Wispr Flow already installed"
else
  echo "    installing Wispr Flow (voice-to-text)..."
  run brew install --cask wispr-flow
fi
step_done

# ---------- Step 5b: Google tools (gog CLI) ----------
# The workspace ships create-or-update-google-doc and create-google-calendar-event,
# and both talk to Google through the gog CLI. Installing it is mechanical; the
# OAuth grant is human and stays out of the script (see the report card).

step_begin "Google tools (gog CLI, for Docs + Calendar skills)"
if command -v gog >/dev/null 2>&1; then
  echo "    gog already installed"
else
  echo "    installing gog (Google Docs + Calendar access)..."
  run brew install openclaw/tap/gogcli
fi
echo "    authorize later with: gog auth add <your-email> --services docs,calendar"
step_done

# ---------- Step 6: GitHub login (browser pause 1 of 2) ----------

# ---------- Access check: is this account entitled to PAOS? ----------
# The template is private and granted per account. Check it BEFORE creating anything,
# so someone without access is told what to do instead of hitting a bare
# "Could not resolve to a Repository" three steps into a half-built workspace.

step_begin "PAOS access"
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "    [dry-run] would check read access to $TEMPLATE_REPO"
elif ! command -v gh >/dev/null 2>&1; then
  echo "    gh not installed yet — will re-check after login"
elif gh repo view "$TEMPLATE_REPO" >/dev/null 2>&1; then
  echo "    access confirmed"
else
  echo ""
  echo "    This account cannot see $TEMPLATE_REPO."
  echo ""
  echo "    PAOS is granted per account. If you believe you should have access, ask"
  echo "    whoever set you up to add your GitHub username; if you are not set up yet,"
  echo "    that is the step that comes before this one."
  echo ""
  echo "    Nothing has been created or changed on this machine."
  exit 3
fi
step_done

step_begin "GitHub login"
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "    [dry-run] would check gh auth status and run 'gh auth login --web' if needed"
elif gh auth status >/dev/null 2>&1; then
  echo "    already logged in as $(gh api user -q .login 2>/dev/null || echo '?')"
else
  echo ""
  echo "    ------------------------------------------------"
  echo "    PAUSE: your browser will open for GitHub login."
  echo "    Accept the defaults, click through, come back here."
  echo "    ------------------------------------------------"
  gh auth login --hostname github.com --git-protocol https --web || on_fail
fi
step_done

# ---------- Step 7: The one question — workspace name ----------

step_begin "Your workspace"
run mkdir -p "$PROJECTS_DIR"

if [[ -z "$WORKSPACE_NAME" ]]; then
  # Idempotency: if exactly one workspace from this template already exists
  # locally, adopt it instead of asking.
  existing=""
  for d in "$PROJECTS_DIR"/*/; do
    [[ -d "$d" ]] || continue
    if [[ -f "$d/AGENTS.md" ]] && git -C "$d" remote get-url upstream 2>/dev/null \
         | grep -qE "$TEMPLATE_REPO|$LEGACY_REPO"; then
      if [[ -z "$existing" ]]; then existing="$(basename "$d")"; else existing="__multiple__"; fi
    fi
  done
  if [[ -n "$existing" && "$existing" != "__multiple__" ]]; then
    WORKSPACE_NAME="$existing"
    echo "    found existing workspace: $WORKSPACE_NAME (adopting it)"
  fi
fi

if [[ -z "$WORKSPACE_NAME" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    WORKSPACE_NAME="my-paos"
    echo "    [dry-run] would ask for a workspace name (using 'my-paos' for this dry run)"
  else
    echo ""
    echo "    The one question: what do you want to name your workspace?"
    echo "    This becomes the GitHub repo name and the folder name."
    echo "    Good options: my-paos, apex-os, <your-name>-command-center"
    echo ""
    while true; do
      printf "    Workspace name [my-paos]: "
      read -r WORKSPACE_NAME
      WORKSPACE_NAME="${WORKSPACE_NAME:-my-paos}"
      if [[ "$WORKSPACE_NAME" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then break; fi
      echo "    Use lowercase letters, digits, and hyphens only (e.g. my-paos)."
    done
  fi
fi

WORKSPACE_DIR="$PROJECTS_DIR/$WORKSPACE_NAME"
step_done

# ---------- Step 8: Create the workspace from the template ----------

step_begin "Create private workspace '$WORKSPACE_NAME' from the template"
if [[ -d "$WORKSPACE_DIR/.git" ]]; then
  echo "    already exists at $WORKSPACE_DIR — leaving it alone"
elif [[ "$DRY_RUN" -eq 1 ]]; then
  echo "    [dry-run] would run: gh repo create $WORKSPACE_NAME --template $TEMPLATE_REPO --private --clone   (in $PROJECTS_DIR)"
else
  GH_USER="$(gh api user -q .login 2>/dev/null || echo "")"
  if [[ -n "$GH_USER" ]] && gh repo view "$GH_USER/$WORKSPACE_NAME" >/dev/null 2>&1; then
    echo "    repo $GH_USER/$WORKSPACE_NAME already exists on GitHub — cloning it"
    (cd "$PROJECTS_DIR" && gh repo clone "$GH_USER/$WORKSPACE_NAME") || on_fail
  else
    (cd "$PROJECTS_DIR" && gh repo create "$WORKSPACE_NAME" --template "$TEMPLATE_REPO" --private --clone) || on_fail
  fi
fi
step_done

# ---------- Step 9: Safety-disabled upstream remote ----------

step_begin "Wire upstream remote (pull template updates, never push back)"
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "    [dry-run] would add upstream https://github.com/$TEMPLATE_REPO.git with push URL DISABLED"
else
  cd "$WORKSPACE_DIR" || on_fail
  if git remote get-url upstream >/dev/null 2>&1; then
    echo "    upstream remote already wired"
  else
    run git remote add upstream "https://github.com/$TEMPLATE_REPO.git"
  fi
  run git remote set-url --push upstream DISABLED
fi
step_done

# ---------- Step 10: Hourly sync ----------

step_begin "Hourly sync (continuous backup to your private GitHub repo)"
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "    [dry-run] would run: bash scripts/install-sync-cron.sh   (in $WORKSPACE_DIR)"
else
  (cd "$WORKSPACE_DIR" && bash scripts/install-sync-cron.sh) || on_fail
fi
step_done

# ---------- Step 11: Install the workspace skills globally (Claude Code plugin) ----------
# The workspace doubles as a Claude Code plugin marketplace (.claude-plugin/),
# so the starter skills work in ANY directory as /paos:<skill>, not only when
# Claude Code is launched inside the workspace. The install is a cached
# snapshot of YOUR clone; after editing skills, run /plugin update paos.

step_begin "Workspace skills everywhere (Claude Code plugin, global)"
# The marketplace MUST resolve to GitHub, not to this clone. Both work — the
# manifest says "source": "./", which resolves to the repo root on GitHub or to
# the local folder depending only on how the marketplace was ADDED. A
# directory-sourced marketplace re-reads THIS folder on every `plugin update`,
# so the operator would get a clean "already up to date" forever and never
# receive a single upstream release. That failure is silent, which is what makes
# it expensive.
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "    [dry-run] would run: claude plugin marketplace add $TEMPLATE_REPO"
  echo "    [dry-run] would run: claude plugin install paos@paos-workspace --yes"
  echo "    [dry-run] would run: claude plugin init my-skills"
elif ! command -v claude >/dev/null 2>&1; then
  echo "    claude not on PATH yet — skipping (rerun this script after Claude Code is installed)"
else
  if claude plugin marketplace list 2>/dev/null | grep -A1 "paos-workspace" | grep -q "Directory"; then
    echo "    migrating paos-workspace from a local directory to GitHub (so releases reach you)..."
    run claude plugin marketplace remove paos-workspace
  fi
  if claude plugin marketplace list 2>/dev/null | grep -q "paos-workspace"; then
    echo "    marketplace already added"
  else
    run claude plugin marketplace add "$TEMPLATE_REPO"
  fi
  if claude plugin list 2>/dev/null | grep -q "paos@paos-workspace"; then
    echo "    plugin already installed"
  else
    run claude plugin install paos@paos-workspace --yes
  fi
  # Skills YOU write live in their own plugin, so a PAOS release can never
  # overwrite them and your own work is never a merge conflict.
  if [[ -d "$HOME/.claude/skills/my-skills" ]]; then
    echo "    personal skills plugin already set up"
  else
    echo "    creating your personal skills plugin (/my-skills:<name>)..."
    run claude plugin init my-skills --description "Your own skills, global as /my-skills:<name> in any directory. PAOS releases never touch these."
    # `plugin init` scaffolds a SINGLE-skill plugin: a placeholder SKILL.md at the
    # root and "skills": ["./"] in the manifest. Two problems for a library that
    # grows: skills added under skills/<name>/ are never loaded, and the
    # placeholder's "TODO" description is loaded into every session forever.
    # Convert to the multi-skill layout immediately.
    if [[ "$DRY_RUN" -eq 0 ]]; then
      rm -f "$HOME/.claude/skills/my-skills/SKILL.md"
      mkdir -p "$HOME/.claude/skills/my-skills/skills"
      python3 - "$HOME/.claude/skills/my-skills/.claude-plugin/plugin.json" <<'PYEOF'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d["skills"]=["./skills/"]
json.dump(d,open(p,'w'),indent=2); open(p,'a').write("\n")
PYEOF
    fi
  fi
fi
step_done

# ---------- Step: the `cici` launcher ----------
#
# WHY THIS EXISTS. CiCi is meant to greet you with what you were last doing, and
# the SessionStart hook already prepares that line. But a hook writes into the
# MODEL'S context, not onto your terminal, and the model does not speak until you
# do. So on a fresh prompt she is silent, and her line only appears buried in the
# reply to whatever you happened to type first. Reported 2026-08-28: "she does not
# say hello in beginning of session btw."
#
# A preloaded prompt fixes it: `claude "<prompt>"` submits as the session opens, so
# the model answers immediately and the continuity line leads it.
#
# THE FLAGS ARE DELIBERATE. DO NOT "HARDEN" THEM AWAY, AND DO NOT LOOSEN THEM.
# This ships --permission-mode auto and --remote-control on purpose. The plain
# form was proposed and rejected by the maintainer on 2026-08-28: PAOS is an
# operator's own workspace on their own machine, and the whole product is an agent
# that acts without being asked to ask. A launcher that stops for a permission
# prompt on every file write is not the experience this system is for. The first
# answer to that was --dangerously-skip-permissions; the maintainer replaced it
# later the same day with --permission-mode auto, which keeps routine work
# unprompted while genuinely risky actions still stop and ask, so a brand-new
# operator does not get a session with no guardrails on day one.
# --remote-control keeps the session reachable from the phone, which is the point
# of launching it this way rather than typing `claude`.
# If you are reading this because it looks unsafe: it was considered, and this is
# the answer. Change it for yourself, not for everyone.

step_begin "The 'cici' launcher"

SHELL_RC="$HOME/.zshrc"
[[ "${SHELL:-}" == *bash* ]] && SHELL_RC="$HOME/.bashrc"

if grep -qs 'PAOS cici launcher' "$SHELL_RC"; then
  echo "    cici launcher already installed in $(basename "$SHELL_RC")"
elif [[ "$DRY_RUN" -eq 1 ]]; then
  echo "    [dry-run] would add the cici() launcher to $SHELL_RC"
else
  cat >> "$SHELL_RC" <<'RCEOF'

# PAOS cici launcher — opens Claude Code with CiCi already speaking.
# A SessionStart hook prepares her continuity line, but hooks write to the model's
# context and the model does not speak until you do, so on a bare prompt she is
# silent. Preloading the skill makes her open the session instead of answering into
# the middle of it. `cici` on its own, or `cici how did my week go`.
# Same flags as a normal PAOS session: auto mode so the agent can work without a
# prompt on every write while risky actions still stop and ask, and remote-control
# so you can pick the session up on your phone.
# THE `--` IS LOAD-BEARING. --remote-control takes an OPTIONAL [name], so without
# the separator the shell hands it the prompt and it is consumed as the session
# NAME. The session then opens with Remote Control on, an empty prompt box, and
# nothing submitted, which looks exactly like the launcher silently not working.
# Caught 2026-08-28 by launching it and seeing an empty box.
cici() { claude --permission-mode auto --remote-control -- "/paos:cici${*:+ $*}"; }
RCEOF
  echo "    added cici() to $(basename "$SHELL_RC") — open a new terminal, then run: cici"
fi
step_done

# ---------- Report card ----------

echo ""
echo "=================================================="
echo "  REPORT CARD"
echo "=================================================="
report() { # report <label> <check-command...>
  local label="$1"; shift
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf "  ▫️ %-22s (dry run)\n" "$label"
  elif "$@" >/dev/null 2>&1; then
    printf "  ✅ %-22s\n" "$label"
  else
    printf "  ❌ %-22s\n" "$label"
  fi
}
report "Homebrew" command -v brew
report "Node.js" command -v node
report "Git" command -v git
report "GitHub CLI" command -v gh
report "GitHub logged in" gh auth status
report "VS Code" test -d "$APPS_DIR/Visual Studio Code.app"
report "Claude Code" command -v claude
report "Granola" test -d "$APPS_DIR/Granola.app"
report "Wispr Flow" test -d "$APPS_DIR/Wispr Flow.app"
report "gog (Google CLI)" command -v gog
report "Workspace cloned" test -d "$WORKSPACE_DIR/.git"
report "Upstream wired" bash -c "git -C '$WORKSPACE_DIR' remote get-url upstream"
report "Hourly sync" bash -c "crontab -l | grep -q '$WORKSPACE_DIR/scripts/sync.sh'"
report "Skills plugin (global)" bash -c "claude plugin list | grep -q 'paos@paos-workspace'"
report "Plugin updatable (GitHub source)" bash -c "claude plugin marketplace list | grep -A1 paos-workspace | grep -q GitHub"
report "Personal skills plugin" test -d "$HOME/.claude/skills/my-skills"
echo ""
echo "  Workspace: $WORKSPACE_DIR"
echo "  Log:       $LOG_FILE"
echo ""
echo "  Still yours to do (judgment calls, not script work):"
echo "  - Sign in to Wispr Flow and start its trial (~\$10/mo after)"
echo "  - Sign in to Granola (free tier is enough to start)"
echo "=================================================="
log_line "=== bootstrap run finished ==="

# ---------- Handoff (browser pause 2 of 2 happens inside the harness) ----------

if [[ "$DRY_RUN" -eq 1 || "$NO_LAUNCH" -eq 1 ]]; then
  echo ""
  echo "Next: cd $WORKSPACE_DIR && claude"
  echo "On first run Claude Code asks you to log in with your Anthropic account"
  echo "(the second and last browser pause). Then the onboard skill takes over."
  exit 0
fi

echo ""
echo "Last step: launching Claude Code inside your new workspace."
echo "On first run it asks you to log in with your Anthropic account (the"
echo "second and last browser pause). After that, the workspace's onboard"
echo "skill takes over: it interviews you and builds your profile."
echo ""
printf "Press Enter to launch (or Ctrl+C to stop here): "
read -r _
cd "$WORKSPACE_DIR" || on_fail
exec claude
