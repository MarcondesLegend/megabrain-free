#!/bin/bash
# pre-push-validation.sh — Pre-push validation hook
# Validates changed YAML files AND registry governance before git push.
#
# Runs:
#   1. npm run validate:yaml:changed — blocks on YAML syntax errors
#   2. node scripts/registry-governance-check.js --mode blocking — blocks on
#      missing registry updates (STORY-131.6 anti-recidiva)
#
# Graceful: continues if individual scripts not found.
#
# Escape hatch for registry check: the operator may append `--skip-registry-check`
# to the `git push` command line (e.g. `git push origin HEAD --skip-registry-check`).
# The hook detects this token, strips it conceptually, and invokes the check
# with the flag so a WARNING (UPPERCASE) is emitted to stderr and push proceeds.
# Mirror pattern of --skip-doctor (STORY-119.1).
#
# Stories:
#   STORY-70.6 AC5 — original YAML pre-push validation
#   STORY-131.6   — registry-governance blocking wiring + escape hatch

INPUT=$(cat)

# Extract command from JSON
COMMAND=$(echo "$INPUT" | node -e "
  let d='';
  process.stdin.on('data',c=>d+=c);
  process.stdin.on('end',()=>{
    try{console.log(JSON.parse(d).tool_input.command||'')}
    catch(e){process.exit(1)}
  });
" 2>/dev/null)

# Only intercept git push commands
if ! echo "$COMMAND" | grep -qiE '\bgit\s+push\b'; then
  exit 0
fi

REPO=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$REPO" ]; then
  exit 0
fi

# ─── Step 1: YAML validation (STORY-70.6 AC5) ───
if [ -f "$REPO/scripts/validate-yaml-incremental.js" ]; then
  if ! node "$REPO/scripts/validate-yaml-incremental.js" >/dev/null 2>&1; then
    REASON="[STORY-70.6 AC5] YAML syntax errors in changed files. Fix before push. Run: npm run validate:yaml:changed"
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}' "$REASON"
    exit 0
  fi
else
  # Graceful: script not found — warn and allow
  echo "WARNING: validate:yaml:changed script not found — YAML pre-push validation skipped" >&2
fi

# ─── Step 2: Registry governance blocking check (STORY-131.6) ───
# Detect escape hatch in the push command line or REGISTRY_SKIP_CHECK env var.
SKIP_REGISTRY_ARG=""
if echo "$COMMAND" | grep -qE -- '--skip-registry-check'; then
  SKIP_REGISTRY_ARG="--skip-registry-check"
elif [ -n "$SKIP_REGISTRY_CHECK" ]; then
  SKIP_REGISTRY_ARG="--skip-registry-check"
fi

if [ -f "$REPO/scripts/registry-governance-check.js" ]; then
  # Capture stderr so the WARNING (when --skip-registry-check is active) reaches the operator.
  REG_OUTPUT=$(node "$REPO/scripts/registry-governance-check.js" --mode blocking $SKIP_REGISTRY_ARG 2>&1)
  REG_EXIT=$?

  # Always forward warnings/errors to stderr for visibility.
  if [ -n "$REG_OUTPUT" ]; then
    echo "$REG_OUTPUT" >&2
  fi

  if [ "$REG_EXIT" -ne 0 ]; then
    REASON="[STORY-131.6] Registry governance BLOCKING check failed. Update the missing registries OR append --skip-registry-check (emits UPPERCASE WARNING and bypasses). Details above."
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}' "$REASON"
    exit 0
  fi
else
  # Graceful: script not found — warn and allow
  echo "WARNING: registry-governance-check.js not found — registry governance pre-push check skipped (STORY-131.6)" >&2
fi

# All checks passed — allow
exit 0
