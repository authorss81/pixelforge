#!/usr/bin/env bash
# Applies branch protection to main.
#
# This is a script and not a GitHub Actions workflow on purpose. The token a
# workflow runs with cannot request the `administration` scope, so a workflow
# that tries to set branch protection always fails. Run this locally with your
# own gh auth, which needs admin on the repository.
#
#   gh auth login
#   bash scripts/apply-branch-protection.sh
#
# What it buys: the merge job in ops.yml calls `gh pr merge --auto`, which hands
# the merge to GitHub. GitHub then waits for the required status checks below.
# Without them, auto-merge resolves the moment the PR is created and a phase
# that has never been compiled lands on main.
#
# The contexts below are the job names of .github/workflows/build.yml. If you
# rename a job there, rename it here too or auto-merge will merge without it.

set -euo pipefail

REPO="${1:-${GITHUB_REPOSITORY:-}}"
if [ -z "$REPO" ]; then
  echo "usage: bash scripts/apply-branch-protection.sh [owner/repo]" >&2
  exit 2
fi

echo "applying branch protection to ${REPO}/main"
echo "  required checks : analyze + test, android, windows"
echo "  strict          : yes (branch must be up to date before merging)"
echo "  merge method    : squash only"
echo

gh api -X PUT "repos/${REPO}/branches/main/protection" \
  -H "Accept: application/vnd.github+json" \
  -H "Content-Type: application/json" \
  -d '{
    "branch": "main",
    "required_status_checks": {
      "strict": true,
      "contexts": ["analyze + test", "android", "windows"]
    },
    "enforce_admins": false,
    "required_pull_request_reviews": null,
    "restrictions": null,
    "required_linear_history": true,
    "allow_force_pushes": false,
    "allow_deletions": false,
    "block_creations": false,
    "required_conversation_resolution": true,
    "lock_branch": false
  }'

echo
echo "branch protection applied"
echo
echo "verify with:"
echo "  gh api repos/${REPO}/branches/main/protection \\"
echo "    --jq '{checks: .required_status_checks.contexts}'"