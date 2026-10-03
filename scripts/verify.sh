#!/usr/bin/env bash
# Fast verification. Run this before touching the ops loop, not after.
#
#   bash scripts/verify.sh              everything
#   bash scripts/verify.sh harness      ops loop only, no Flutter, ~40s
#   bash scripts/verify.sh app          Flutter analyze + test only
#
# The harness tests run scripts/phase_runner.sh against a stub `opencode` in a
# throwaway git repo. That is the whole point: every bug that cost a day on
# this project was in phase_runner.sh, and every one of them is reachable in
# under a minute without spending an agent run.
#
# Bugs this exists to catch, all of which shipped and cost real time:
#   - work detection reporting "no work" because the checkpoint loop had already
#     committed the changes
#   - rate-limit classification firing on the agent's own prose
#   - a single shared wip branch being overwritten by the next attempt
#   - markers never reaching main, so the attempt cap could never trigger
#   - capture_session writing the run title as a session id

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; OFF=$'\033[0m'
PASS=0; FAIL=0; FAILED_NAMES=()

ok()   { printf '  %sPASS%s %s\n' "$GREEN" "$OFF" "$1"; PASS=$((PASS+1)); }
bad()  { printf '  %sFAIL%s %s\n' "$RED" "$OFF" "$1"; FAIL=$((FAIL+1)); FAILED_NAMES+=("$1"); }
head_() { printf '\n%s%s%s\n' "$DIM" "$1" "$OFF"; }

# --------------------------------------------------------------------------
section_syntax() {
  head_ "shell syntax"
  local f
  for f in scripts/phase_runner.sh scripts/apply-branch-protection.sh scripts/verify.sh; do
    if bash -n "$f" 2>/dev/null; then ok "$f parses"; else bad "$f has a syntax error"; fi
  done

  head_ "workflow yaml"
  if command -v python >/dev/null 2>&1 && python -c "import yaml" 2>/dev/null; then
    for f in .github/workflows/*.yml; do
      [ -e "$f" ] || continue
      if python -c "import yaml,sys; yaml.safe_load(open(sys.argv[1],encoding='utf-8'))" "$f" 2>/dev/null; then
        ok "$(basename "$f") parses"
      else
        bad "$(basename "$f") is not valid yaml"
      fi
    done
  else
    printf '  %sskip%s yaml checks (no python yaml)\n' "$YELLOW" "$OFF"
  fi

  head_ "workflow hygiene"
  local wf=".github/workflows/ops.yml"
  if grep -q 'workflows: write' "$wf"; then
    ok "ops.yml requests workflows: write (needed to push workflow edits)"
  else
    bad "ops.yml lacks 'workflows: write'; any phase editing a workflow file cannot push"
  fi
  if grep -q 'export PATH="$HOME/.opencode/bin:$PATH"' "$wf"; then
    ok "ops.yml exports PATH inside the install step"
  else
    bad "ops.yml install step has no local PATH export; it will exit 127"
  fi
  if grep -q 'pr create' "$wf"; then
    bad "ops.yml still creates pull requests; GITHUB_TOKEN PRs never get CI"
  else
    ok "ops.yml has no pull-request path"
  fi
}

# --------------------------------------------------------------------------
section_harness() {
  head_ "phase_runner.sh unit checks (sourced functions, seconds, no agent)"
  (
    export PHASE_RUNNER_SOURCED=1
    PHASE=phase-99 PHASE_DIR="workspace/phase-99" LOG_DIR=logs
    # shellcheck disable=SC1091
    . "$REPO_ROOT/scripts/phase_runner.sh"

    # --- classifiers -------------------------------------------------------
    echo "x" > /tmp/vh_clean.log
    if log_is_rate_limited /tmp/vh_clean.log; then
      bad "classifier fires on a clean log"
    else
      ok "classifier silent on a clean log"
    fi

    printf 'working\nHTTP 429 Too Many Requests\n' > /tmp/vh_429.log
    if log_is_rate_limited /tmp/vh_429.log; then
      ok "classifier fires on a real 429"
    else
      bad "classifier misses a real 429"
    fi

    printf 'model not found: opencode/nope\n' > /tmp/vh_model.log
    if log_is_model_error /tmp/vh_model.log; then
      ok "classifier fires on an unknown model"
    else
      bad "classifier misses an unknown model"
    fi
    rm -f /tmp/vh_clean.log /tmp/vh_429.log /tmp/vh_model.log

    # --- marker accounting -------------------------------------------------
    if [ "$(read_attempts /nonexistent/file 2>/dev/null)" = "0" ]; then
      ok "missing attempts file reads as 0"
    else
      bad "missing attempts file does not read as 0"
    fi
    echo "3" > /tmp/vh_att.txt
    if [ "$(read_attempts /tmp/vh_att.txt)" = "3" ]; then
      ok "attempts file reads its value"
    else
      bad "attempts file misread"
    fi
    rm -f /tmp/vh_att.txt

    # --- defer requires empty hands -----------------------------------------
    # This is the structural guarantee that a successful phase can never be
    # deferred: the defer branch conjoins the classifier with no-work.
    if grep -q 'log_is_rate_limited.*&& ! tree_has_real_work' "$REPO_ROOT/scripts/phase_runner.sh"; then
      ok "deferral is gated on no-work, so success can never defer"
    else
      bad "deferral is not gated on no-work; a successful phase can be deferred by its own prose"
    fi

    # --- work detection, in a throwaway repo --------------------------------
    WT="$(mktemp -d)"
    (
      cd "$WT" || exit 1
      git init -q -b main
      git config user.email t@t; git config user.name t; git config commit.gpgsign false
      mkdir -p workspace/phase-99
      printf 'x\n' > file.txt
      git add -A && git commit -q -m init
      PHASE_BASE="$(git rev-parse HEAD)"

      # clean tree, nothing new: no work
      if tree_has_real_work; then
        echo "FAIL clean"
      else
        echo "PASS clean"
      fi

      # uncommitted change: work
      echo "change" > new.txt
      if tree_has_real_work; then
        echo "PASS uncommitted"
      else
        echo "FAIL uncommitted"
      fi
      git add -A && git commit -q -m wip

      # committed since PHASE_BASE: still work
      if tree_has_real_work; then
        echo "PASS committed"
      else
        echo "FAIL committed"
      fi

      # marker-only change after a reset: no work
      git reset -q --hard "$PHASE_BASE"
      echo 1 > workspace/phase-99/.attempts
      if tree_has_real_work; then
        echo "FAIL markers"
      else
        echo "PASS markers"
      fi
    ) > /tmp/vh_work.txt 2>&1

    for c in clean uncommitted committed markers; do
      if grep -q "PASS $c" /tmp/vh_work.txt; then
        ok "work detection: $c tree classified correctly"
      else
        bad "work detection: $c tree misclassified"
      fi
    done
    rm -f /tmp/vh_work.txt
    rm -rf "$WT"
  )
}

section_app() {
  head_ "flutter"
  if ! command -v flutter >/dev/null 2>&1; then
    printf '  %sskip%s flutter not on PATH\n' "$YELLOW" "$OFF"; return
  fi
  flutter pub get >/dev/null 2>&1 || { bad "flutter pub get"; return; }
  if flutter analyze 2>&1 | tail -3 | grep -q 'No issues found'; then
    ok "flutter analyze clean"
  else
    bad "flutter analyze reported issues"; flutter analyze 2>&1 | tail -12
  fi
  if flutter test 2>&1 | tail -3 | grep -q 'All tests passed'; then
    ok "flutter test green"
  else
    bad "flutter test failed"; flutter test 2>&1 | tail -25
  fi
}

section_privacy() {
  head_ "privacy invariants"
  if grep -q 'android.permission.INTERNET' android/app/src/main/AndroidManifest.xml 2>/dev/null; then
    if grep -q 'uses-permission.*INTERNET' android/app/src/main/AndroidManifest.xml 2>/dev/null; then
      bad "the release manifest requests INTERNET"
    else
      ok "INTERNET appears only in a comment, not as a permission"
    fi
  else
    ok "release manifest mentions no INTERNET permission"
  fi
  if grep -q 'tests/privacy_test' test/privacy_test.dart 2>/dev/null || grep -q 'INTERNET' test/privacy_test.dart 2>/dev/null; then
    ok "privacy_test.dart still asserts on INTERNET"
  else
    bad "privacy_test.dart no longer asserts on INTERNET"
  fi
}

main() {
  local what="${1:-all}"
  printf '%spixelforge verify%s\n' "$YELLOW" "$OFF"
  section_syntax
  section_harness
  [ "$what" = "harness" ] && { printf '\n'; summary; exit $?; }
  section_privacy
  section_app
  printf '\n'
  summary
}

summary() {
  printf '%s%d passed%s' "$GREEN" "$PASS" "$OFF"
  if [ "$FAIL" -gt 0 ]; then
    printf ', %s%d failed%s\n' "$RED" "$FAIL" "$OFF"
    for n in "${FAILED_NAMES[@]}"; do printf '  - %s\n' "$n"; done
    return 1
  fi
  printf '\n'
  return 0
}

main "$@"