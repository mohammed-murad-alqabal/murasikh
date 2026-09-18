#!/bin/bash
git checkout main
git pull origin main

SUCCESSFUL_BRANCHES=()
FAILED_BRANCHES=()

# Read branches, strip whitespace and 'origin/' prefix
branches=$(git branch -r | grep -v 'origin/main' | grep -v 'HEAD' | sed -e 's/^[[:space:]]*//' -e 's/^origin\///')

for branch in $branches; do
  echo "==================================="
  echo "Merging $branch..."
  if git merge --no-ff "origin/$branch" -m "Merge $branch into main"; then
    SUCCESSFUL_BRANCHES+=("$branch")
  else
    echo "Conflict detected in $branch. Aborting merge."
    git merge --abort
    FAILED_BRANCHES+=("$branch")
  fi
done

echo "==================================="
echo "Pushing main..."
git push origin main

echo "==================================="
if [ ${#SUCCESSFUL_BRANCHES[@]} -eq 0 ]; then
  echo "No successful merges."
else
  echo "Deleting merged remote branches..."
  for branch in "${SUCCESSFUL_BRANCHES[@]}"; do
    git push origin --delete "$branch"
  done
fi

echo "==================================="
echo "Failed merges (requires manual resolution):"
for branch in "${FAILED_BRANCHES[@]}"; do
  echo "  - $branch"
done

