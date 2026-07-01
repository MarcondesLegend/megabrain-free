#!/bin/bash
# enforce-quality-first.sh — Constitutional Article V Enforcement
# PreToolUse hook: runs incremental YAML validation before git push
#
# Checks run (in order, fail-fast):
#   0. doctor — Full system health check (BLOCK on any FAIL)
#   1. validate:yaml:changed — YAML syntax on changed files (<1s)
#   2. validate:squads — Squad structure validation
#
# Mode: BLOCK on YAML errors, WARN on squad errors
# Flag: --skip-doctor bypasses doctor check (emergency use only)
#
# Story: STORY-111.4 (Epic 111 — Governance Enforcement Closure)
#        STORY-119.1 (Epic 119 — Doctor Gate Bloqueante)
# Constitution: Article V — Quality First

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

# Only check git push commands
if ! echo "$COMMAND" | grep -qiE '\bgit\s+push\b'; then
  exit 0
fi

REPO=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$REPO" ]; then
  exit 0
fi

# 0. Doctor gate (BLOCK on any FAIL)
if echo "$COMMAND" | grep -q '\-\-skip-doctor'; then
  echo "WARNING: --SKIP-DOCTOR FLAG DETECTED. DOCTOR GATE BYPASSED. THIS IS AN EMERGENCY OVERRIDE — BROKEN STATE MAY BE PUSHED. ENSURE YOU FIX FAILURES IMMEDIATELY AFTER." >&2
else
  if [ -f "$REPO/scripts/doctor.js" ]; then
    DOCTOR_OUTPUT=$(node "$REPO/scripts/doctor.js" 2>&1)
    DOCTOR_EXIT=$?
    if [ $DOCTOR_EXIT -ne 0 ]; then
      FAIL_LINES=$(echo "$DOCTOR_OUTPUT" | grep -E '(FAIL|✗|ERROR)' | head -20 | sed 's/^[[:space:]]*/  /')
      REASON="[Art. V + Story-119.1] Doctor reported failures — push blocked. Fix all FAILs before pushing. Run: npm run doctor | Emergency bypass: git push --skip-doctor | Failures: ${FAIL_LINES}"
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}' "$(echo "$REASON" | tr '"' "'" | tr '\n' ' ')"
      exit 0
    fi
  fi
fi

# 1. YAML incremental validation (BLOCK)
if [ -f "$REPO/scripts/validate-yaml-incremental.js" ]; then
  if ! node "$REPO/scripts/validate-yaml-incremental.js" >/dev/null 2>&1; then
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"[Art. V] YAML syntax errors in changed files. Fix before push. Run: npm run validate:yaml:changed"}}'
    exit 0
  fi
fi

# 2. Squad structure validation (WARN — logs but allows)
if [ -f "$REPO/scripts/validate-squads.js" ]; then
  if ! node "$REPO/scripts/validate-squads.js" >/dev/null 2>&1; then
    echo "⚠️  [Art. V] Squad structure validation warnings. Run: npm run validate:squads" >&2
  fi
fi

# All checks passed — allow
exit 0
