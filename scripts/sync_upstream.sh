#!/bin/bash
# sync_upstream.sh - Sync fork with upstream RustDesk
# Usage: ./sync_upstream.sh [--merge-custom]

set -e

UPSTREAM_BRANCH="master"
ORIGIN_BRANCH="master"
DEVELOP_BRANCH="develop"
CUSTOM_BRANCHES=(
  "custom/screen-wall"
  "custom/ui-overhaul"
  "custom/background-service"
  "custom/background-input"
)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[sync]${NC} $1"; }
warn() { echo -e "${YELLOW}[warn]${NC} $1"; }
err()  { echo -e "${RED}[error]${NC} $1"; }

# Ensure clean working tree
if [ -n "$(git status --porcelain)" ]; then
  err "Working tree is dirty. Commit or stash changes first."
  exit 1
fi

CURRENT_BRANCH=$(git branch --show-current)

# Step 1: Fetch upstream
log "Fetching upstream..."
git fetch upstream

# Step 2: Sync master with upstream
log "Syncing $ORIGIN_BRANCH with upstream/$UPSTREAM_BRANCH..."
git checkout "$ORIGIN_BRANCH"
BEFORE=$(git rev-parse HEAD)
git merge "upstream/$UPSTREAM_BRANCH" --no-edit
AFTER=$(git rev-parse HEAD)

if [ "$BEFORE" = "$AFTER" ]; then
  log "master is already up to date."
else
  NEW_COMMITS=$(git log --oneline "$BEFORE".."$AFTER" | wc -l | tr -d ' ')
  log "Merged $NEW_COMMITS new commits from upstream."
  git push origin "$ORIGIN_BRANCH"
fi

# Step 3: Merge master into develop
log "Merging $ORIGIN_BRANCH into $DEVELOP_BRANCH..."
git checkout "$DEVELOP_BRANCH"
git merge "$ORIGIN_BRANCH" --no-edit
git push origin "$DEVELOP_BRANCH"

# Step 4: Optionally merge develop into custom branches
if [ "$1" = "--merge-custom" ]; then
  for branch in "${CUSTOM_BRANCHES[@]}"; do
    if git show-ref --verify --quiet "refs/heads/$branch"; then
      log "Merging $DEVELOP_BRANCH into $branch..."
      git checkout "$branch"
      if git merge "$DEVELOP_BRANCH" --no-edit; then
        log "$branch merged successfully."
        git push origin "$branch"
      else
        err "Conflict merging $DEVELOP_BRANCH into $branch. Resolve manually."
        git merge --abort
        warn "Skipped $branch."
      fi
    else
      warn "Branch $branch does not exist locally, skipping."
    fi
  done
fi

# Return to original branch
git checkout "$CURRENT_BRANCH"
log "Done."
