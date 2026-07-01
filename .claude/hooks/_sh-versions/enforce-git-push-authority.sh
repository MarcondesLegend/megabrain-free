#!/bin/bash
# enforce-git-push-authority.sh (project-level override)
# PreToolUse hook: blocks "git push" unless @devops agent is active
# Fix: checks MEGABRAIN_ACTIVE_AGENT (canonical) and MEGABRAIN_ACTIVE_AGENT (legacy) — allows push for devops/github-devops
# Uses node (not jq) for JSON parsing — works on Windows/Git Bash
# FAIL-CLOSED: if parsing fails, blocks the command

INPUT=$(cat)

# Extract command from JSON using node (available on all Mega Brain systems)
COMMAND=$(echo "$INPUT" | node -e "
  let d='';
  process.stdin.on('data',c=>d+=c);
  process.stdin.on('end',()=>{
    try{console.log(JSON.parse(d).tool_input.command||'')}
    catch(e){process.exit(1)}
  });
" 2>/dev/null)

# Fail-closed: if node parsing failed, block the command
if [ $? -ne 0 ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Hook failed to parse input — blocking for safety. Contact @devops."}}'
  exit 0
fi

# Only check git push commands
if echo "$COMMAND" | grep -qiE '\bgit\s+push\b'; then
  # Allow if @devops agent is active (devops or github-devops for backward compat)
  # Check both Mega Brain (canonical) and Mega Brain (legacy) for backward compat
  if [ "$MEGABRAIN_ACTIVE_AGENT" = "devops" ] || [ "$MEGABRAIN_ACTIVE_AGENT" = "github-devops" ] \
  || [ "$MEGABRAIN_ACTIVE_AGENT" = "devops" ] || [ "$MEGABRAIN_ACTIVE_AGENT" = "github-devops" ]; then
    exit 0
  fi

  # Also check if the command itself sets the env var inline
  if echo "$COMMAND" | grep -qiE 'MEGABRAIN_ACTIVE_AGENT=devops|MEGABRAIN_ACTIVE_AGENT=devops'; then
    exit 0
  fi

  # Block for all other agents — build a helpful error message
  ACTIVE="${MEGABRAIN_ACTIVE_AGENT:-unknown}"
  REASON="BLOCKED: \`git push\` is exclusive to @devops (Constitution II). Current agent: @${ACTIVE}. Delegate to a devops subagent or use /commit to push."
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"${REASON}\"}}"
  exit 0
fi

# Allow all other commands
exit 0
