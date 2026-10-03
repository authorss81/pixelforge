#!/usr/bin/env bash
# PixelForge phase runner.
#
# Drives one phase of the self-dispatching ops loop. Phase state lives in git
# under workspace/<phase>/ as marker files, so any tick can resume with no
# external state at all.
#
# Markers, all inside workspace/<phase>/:
#   .done            phase completed and verified
#   .blocked         exceeded MAX_ATTEMPTS, needs a human
#   .deferred        rate limited or transient env failure, retriable, NOT an attempt
#   .attempts        integer count of real work attempts
#   .deferred_attempts  integer count of deferrals
#   .no_work         agent exited 0 but changed nothing that mattered
#   .session         opencode session id for continuity
#   .timeout         optional per-phase runner timeout in minutes, default 90
#
# workspace/.stop halts the whole pipeline.
#
# Usage:
#   phase_runner.sh <phase>                 run the phase
#   phase_runner.sh <phase> --review-only   review + fix existing phase changes
#
# Exit codes:
#   0  success
#   1  work failure (counts toward MAX_ATTEMPTS)
#   2  no work done (retryable, counts as an attempt)
#   5  transient / rate limited (retryable, does NOT count as an attempt)
#   6  blocked, manual intervention needed

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$REPO_ROOT"

PHASE="${1:-}"
MODE="run"
if [ "${2:-}" = "--review-only" ]; then MODE="review"; fi

LOG_DIR="logs"
PHASE_DIR="workspace/${PHASE}"
DONE_FILE="${PHASE_DIR}/.done"
BLOCKED_FILE="${PHASE_DIR}/.blocked"
ATTEMPTS_FILE="${PHASE_DIR}/.attempts"
DEFERRED_FILE="${PHASE_DIR}/.deferred"
DEFERRED_ATTEMPTS_FILE="${PHASE_DIR}/.deferred_attempts"
NO_WORK_FILE="${PHASE_DIR}/.no_work"
SESSION_FILE="${PHASE_DIR}/.session"
PROMPT_FILE="${PHASE_DIR}/PROMPT.md"
STOP_FILE="workspace/.stop"

MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}"
CHECKPOINT_SECONDS="${CHECKPOINT_SECONDS:-300}"
WIP_BRANCH_PREFIX="${WIP_BRANCH_PREFIX:-pf-bot/wip}"
REVIEWER_AGENT="${REVIEWER_AGENT:-reviewer}"
BUILD_AGENT="${BUILD_AGENT:-build}"

# Primary model first, then the free-tier fallback chain. The runner advances
# only on MODEL-level failures, never on a real work failure.
MODELS_RAW="${OPENCODE_MODEL:-opencode/space-bunny-free}"
IFS=',' read -r -a MODELS <<< "$MODELS_RAW"

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
log()  { echo "== [$PHASE] $*"; }
warn() { echo "== [$PHASE] WARN: $*"; }
die()  { log "FATAL: $*"; exit 1; }

ensure_log_dir() { mkdir -p "$LOG_DIR"; }

marker_paths() {
  echo "logs/|workspace/\.|^workspace/[^/]+/\.|\.log$|wip/|pf-bot/"
}

# Does the working tree contain changes a phase could plausibly have made?
tree_has_real_work() {
  local changed
  changed="$(git status --porcelain \
    | grep -Ev "$(marker_paths)" \
    | grep -Ev '^\?\? logs/' || true)"
  [ -n "$changed" ]
}

tree_diff_has_real_work() {
  local changed
  changed="$(git diff --name-only HEAD \
    | grep -Ev "$(marker_paths)" || true)"
  [ -n "$changed" ]
}

read_attempts() {
  local f="$1"
  if [ -f "$f" ]; then tr -dc '0-9' < "$f"; else echo 0; fi
}

# ---------------------------------------------------------------------------
# rate limit / model classification
# ---------------------------------------------------------------------------
log_is_rate_limited() {
  grep -qiE "HTTP[ /]?429|429[^0-9]|too many requests|rate[ _-]?limit|insufficient[ _-]?quota|quota exceeded|overloaded|temporarily unavailable|connection reset|ETIMEDOUT|ENOTFOUND|socket hang up" \
    "$1" 2>/dev/null && return 0
  return 1
}

log_is_model_error() {
  grep -qiE "model not found|unknown model|invalid model|no such model|provider not found|502|503|504|streaming response failed" \
    "$1" 2>/dev/null && return 0
  return 1
}

# ---------------------------------------------------------------------------
# preflight
# ---------------------------------------------------------------------------
preflight() {
  ensure_log_dir

  if [ -z "$PHASE" ]; then die "no phase given"; fi
  if [ ! -d "$PHASE_DIR" ]; then die "no such phase dir: $PHASE_DIR"; fi
  if [ ! -f "$PROMPT_FILE" ]; then die "missing prompt: $PROMPT_FILE"; fi

  if ! command -v opencode >/dev/null 2>&1; then
    warn "opencode binary not on PATH"
    return 1
  fi
  if [ -z "${OPENCODE_API_KEY:-}" ]; then
    warn "OPENCODE_API_KEY not set"
    return 1
  fi
  if ! opencode models >/dev/null 2>&1; then
    warn "opencode models failed, credentials or network problem"
    return 1
  fi

  git config user.name "pixelforge-bot" >/dev/null 2>&1 || true
  git config user.email "pixelforge-bot@users.noreply.github.com" >/dev/null 2>&1 || true
  return 0
}

# ---------------------------------------------------------------------------
# checkpoint loop: commit WIP so a timeout cannot destroy work
# ---------------------------------------------------------------------------
checkpoint_loop() {
  local local_branch
  local_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
  while true; do
    sleep "$CHECKPOINT_SECONDS"
    if tree_has_real_work; then
      git add -A >/dev/null 2>&1 || true
      if ! git diff --cached --quiet 2>/dev/null; then
        git commit -q -m "wip(${PHASE}): checkpoint" >/dev/null 2>&1 || true
        git push -q -f origin "HEAD:refs/heads/${WIP_BRANCH_PREFIX}/${PHASE}" >/dev/null 2>&1 || true
        log "checkpoint committed and pushed (was on ${local_branch})"
      fi
    fi
  done
}

# ---------------------------------------------------------------------------
# context header: the agent reads workspace/<phase>/PROMPT.md itself, so only a
# compact header goes over stdin. The full prompt is kept as a commit audit record.
# ---------------------------------------------------------------------------
build_context_header() {
  local attempts deferred
  attempts="$(read_attempts "$ATTEMPTS_FILE")"
  deferred="$(read_attempts "$DEFERRED_ATTEMPTS_FILE")"

  {
    echo "# PixelForge phase ${PHASE}"
    echo
    echo "Attempt ${attempts} of ${MAX_ATTEMPTS} (${deferred} deferrals so far)."
    echo
    echo "Your task is in ${PROMPT_FILE}. Read it first, then do exactly that."
    echo
    echo "Repo facts:"
    echo "  Flutter 3.44.8 / Dart 3.12.2, pinned in .github/workflows/ops.yml"
    echo "  Verify with: flutter analyze && flutter test"
    echo "  Architecture and the rules you must follow are in AGENTS.md. Read it."
    echo "  The roadmap this phase comes from is ROADMAP.md."
    echo
    echo "Non-negotiables:"
    echo "  1. The Android release manifest must keep requesting ZERO permissions."
    echo "  2. No networking package, no HTTP client, no socket, anywhere."
    echo "  3. Never weaken or delete a test to make it pass."
    echo "  4. Never silently degrade output. If something cannot be preserved, say so."
    echo "  5. Keep flutter analyze clean. It must have zero issues, not zero errors."
    echo "  6. Stay inside this phase's scope. Unrelated cleanup is a separate phase."
  } > "${LOG_DIR}/${PHASE}.ctx"

  {
    cat "${LOG_DIR}/${PHASE}.ctx"
    echo
    echo "----- ${PROMPT_FILE} -----"
    cat "$PROMPT_FILE"
  } > "${LOG_DIR}/${PHASE}.prompt"
}

# ---------------------------------------------------------------------------
# run the model chain
# ---------------------------------------------------------------------------
ACTIVE_MODEL=""
run_models() {
  local logfile="$1"; shift
  local m code pre post growth
  : > "$logfile"
  ACTIVE_MODEL=""

  for m in "${MODELS[@]}"; do
    m="$(echo "$m" | tr -d '[:space:]')"
    [ -n "$m" ] || continue
    echo "== [models] trying ${m} ==" >> "$logfile"
    pre="$(wc -c < "$logfile" 2>/dev/null || echo 0)"

    set +e
    if [ -f "${LOG_DIR}/${PHASE}.ctx" ]; then
      # Re-read the ctx per attempt. Piping it once exhausts stdin and every
      # later model in the chain gets nothing.
      opencode run --model "$m" "$@" < "${LOG_DIR}/${PHASE}.ctx" >> "$logfile" 2>&1
      code=$?
    else
      opencode run --model "$m" "$@" >> "$logfile" 2>&1
      code=$?
    fi
    set -e

    post="$(wc -c < "$logfile" 2>/dev/null || echo 0)"
    growth=$((post - pre))
    log "model ${m} exit=${code} bytes=${growth}"

    if [ "$code" -eq 0 ] && [ "$growth" -gt 0 ]; then
      ACTIVE_MODEL="$m"
      echo "== [models] ${m} succeeded ==" >> "$logfile"
      return 0
    fi

    if [ "$code" -eq 0 ] && [ "$growth" -le 0 ]; then
      warn "model ${m} produced no output, trying next"
      continue
    fi

    # Only model-level and transport failures advance the chain. A non-zero
    # exit after real work means the work failed, and re-running the same task
    # on twenty models would just burn the attempt budget.
    if log_is_rate_limited "$logfile" || log_is_model_error "$logfile"; then
      warn "model ${m} unavailable or rate limited, advancing chain"
      continue
    fi

    echo "== [models] ${m} did real work and failed, stopping chain ==" >> "$logfile"
    return "$code"
  done

  ACTIVE_MODEL=""
  return 1
}

capture_session() {
  local sid
  sid="$(opencode session list 2>/dev/null | tail -1 | awk '{print $2}' || true)"
  if [ -n "$sid" ]; then
    echo "$sid" > "$SESSION_FILE"
    log "session captured: $sid"
  fi
}

# ---------------------------------------------------------------------------
# phase run
# ---------------------------------------------------------------------------
run_phase() {
  if [ -f "$DONE_FILE" ]; then
    log "already .done, nothing to do"
    return 0
  fi
  if [ -f "$BLOCKED_FILE" ]; then
    log "already .blocked, skipping until a human removes the marker"
    return 6
  fi

  local attempt
  attempt=$(( $(read_attempts "$ATTEMPTS_FILE") + 1 ))
  echo "$attempt" > "$ATTEMPTS_FILE"
  rm -f "$DEFERRED_FILE" "$NO_WORK_FILE"
  log "attempt ${attempt} of ${MAX_ATTEMPTS}"

  build_context_header

  checkpoint_loop &
  local checkpoint_pid=$!

  local code
  set +e
  run_models "${LOG_DIR}/${PHASE}.log" \
    --agent "$BUILD_AGENT" \
    --title "pixelforge-${PHASE}"
  code=$?
  set -e

  kill "$checkpoint_pid" >/dev/null 2>&1 || true

  if [ -n "$ACTIVE_MODEL" ]; then
    log "model used: $ACTIVE_MODEL"
    capture_session
  fi

  # opencode stores sessions on local disk, which the runner wipes between runs.
  # A committed .session marker then points at an id that no longer exists.
  if [ "$code" -ne 0 ] && grep -qi "session not found" "${LOG_DIR}/${PHASE}.log" 2>/dev/null; then
    warn "stale session marker, clearing it so the next tick starts fresh"
    rm -f "$SESSION_FILE"
    echo "$(( $(read_attempts "$ATTEMPTS_FILE") - 1 ))" > "$ATTEMPTS_FILE"
    return 5
  fi

  if log_is_rate_limited "${LOG_DIR}/${PHASE}.log"; then
    warn "rate limited, deferring without burning an attempt"
    touch "$DEFERRED_FILE"
    local d
    d=$(( $(read_attempts "$DEFERRED_ATTEMPTS_FILE") + 1 ))
    echo "$d" > "$DEFERRED_ATTEMPTS_FILE"
    echo "$(( $(read_attempts "$ATTEMPTS_FILE") - 1 ))" > "$ATTEMPTS_FILE"
    return 5
  fi

  if [ "$code" -ne 0 ]; then
    if tree_has_real_work; then
      warn "agent failed but left work in the tree, preserving it for the reviewer"
      return 1
    fi
    warn "agent failed with no changes"
    return 1
  fi

  # Exit 0 is not success if nothing changed.
  if ! tree_has_real_work && ! tree_diff_has_real_work; then
    warn "agent exited 0 but changed nothing relevant"
    touch "$NO_WORK_FILE"
    return 2
  fi

  log "work present, verifying"
  if ! verify; then
    warn "verification failed"
    return 1
  fi

  touch "$DONE_FILE"
  log "phase complete"
  return 0
}

# ---------------------------------------------------------------------------
# review + fix
# ---------------------------------------------------------------------------
run_review() {
  [ -f "$DONE_FILE" ] || { warn "phase not .done, nothing to review"; return 0; }

  log "running reviewer subagent"
  local code
  set +e
  run_models "${LOG_DIR}/${PHASE}.review.log" \
    --agent "$REVIEWER_AGENT" \
    "Review all changes in phase '${PHASE}'. Output a numbered FINDINGS list."
  code=$?
  set -e
  log "review exit: ${code}"

  if [ "$code" -ne 0 ]; then
    # A failed review must never invalidate a phase that already passed.
    warn "review did not complete cleanly, keeping the phase as-is"
    return 0
  fi

  if grep -qiE "FINDINGS:[[:space:]]*[0-9]+|^[[:space:]]*[0-9]+\." "${LOG_DIR}/${PHASE}.review.log" 2>/dev/null; then
    log "applying review fixes"
    set +e
    run_models "${LOG_DIR}/${PHASE}.fix.log" \
      --agent "$BUILD_AGENT" \
      "Fix every finding in ${LOG_DIR}/${PHASE}.review.log. Do not weaken any test. Do not touch the privacy invariants. Then run flutter analyze and flutter test and make both clean."
    set -e
    verify || warn "post-review verification failed, leaving the fixes in place for a human"
  fi

  rm -f "${LOG_DIR}/${PHASE}.review.log" "${LOG_DIR}/${PHASE}.fix.log"
  return 0
}

# ---------------------------------------------------------------------------
# verification: the gate that decides whether a phase is allowed to land
# ---------------------------------------------------------------------------
verify() {
  log "verifying with flutter analyze + flutter test"

  if ! command -v flutter >/dev/null 2>&1; then
    warn "flutter not on PATH, cannot verify, failing closed"
    return 1
  fi

  flutter pub get >> "${LOG_DIR}/${PHASE}.verify.log" 2>&1 || {
    warn "pub get failed"
    return 1
  }
  flutter analyze >> "${LOG_DIR}/${PHASE}.verify.log" 2>&1 || {
    warn "flutter analyze failed, see ${LOG_DIR}/${PHASE}.verify.log"
    return 1
  }
  flutter test >> "${LOG_DIR}/${PHASE}.verify.log" 2>&1 || {
    warn "flutter test failed, see ${LOG_DIR}/${PHASE}.verify.log"
    return 1
  }

  log "verification passed"
  return 0
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
  ensure_log_dir

  if [ "$MODE" = "review" ]; then
    preflight || return 5
    run_review
    return $?
  fi

  preflight || return 5

  if [ -f "$STOP_FILE" ]; then
    log "workspace/.stop present, pipeline halted"
    return 0
  fi

  run_phase
  local code=$?

  if [ "$code" -eq 1 ] || [ "$code" -eq 2 ]; then
    local attempts
    attempts="$(read_attempts "$ATTEMPTS_FILE")"
    if [ "$attempts" -ge "$MAX_ATTEMPTS" ]; then
      warn "attempt cap ${MAX_ATTEMPTS} reached, blocking"
      touch "$BLOCKED_FILE"
      return 6
    fi
    warn "retryable failure, attempt ${attempts}/${MAX_ATTEMPTS}"
  fi

  return "$code"
}

main
exit $?