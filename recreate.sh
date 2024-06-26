#!/usr/bin/env bash

# Setup: Create a PR that can be rebased on top of two branches.
#   Be sure that the `concurrency` settings in the github action is configured to cancel
#   duplicate CI on the same PR.
#
# Usage: Call with:
#    - GH API Token
#    - Details of PR (owner, name, number)
#    - The branch to rebase the PR onto
#    - The branch the PR is currently based on
#
# This needs to be called from the repository the PR is from.
#
# The script will rebase the PR onto the specified branch, then
# push that change AND make an API call to update the base branch.
#
# It will then wait 30 seconds for GH to detect the changes and trigger
# CI.
#
# It may take a few tries of switching the branches back and forth, but
# eventually you will see results where there are 2 CI results and the
# second is canceled. However, that canceled run is being used as the
# run that is reported on the PR.
#

main() {
  local apiToken="$1"
  local repoOwner="$2"
  local repoName="$3"
  local prNumber="$4"
  local nextBranch="$5"
  local prevBranch="$6"

  local targetBranch="$(git rev-parse --abbrev-ref HEAD)"

  # make a change on next branch to ensure commit hashes change
  git checkout $nextBranch
  echo "a line" >> updates.txt
  git add .
  git commit -m "updates"
  git push

  git checkout $targetBranch

  # switch what this branch is targeting.
  git rebase --onto $nextBranch $prevBranch $targetBranch
  local gitSha=$(git rev-parse HEAD)
  git push --force
  sleep 5
  curl -L \
    -X PATCH \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $apiToken" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/repos/$repoOwner/$repoName/pulls/$prNumber \
    -d "{\"base\":\"$nextBranch\"}"

    echo "Waiting 30 seconds for CI to start..."
    sleep 30 # wait for CI to start

    local ciJson=$(curl -L \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer $apiToken" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      https://api.github.com/repos/$repoOwner/$repoName/commits/$gitSha/check-suites)

    # uncomment for all CI details
    # echo "$ciJson" | jq '."check_suites"[] | select(.app.slug=="github-actions")'
    echo "$ciJson" | jq '."check_suites"[] | select(.app.slug=="github-actions") | {id: .id, slug: .app.slug, node_id: .node_id, status: .status, conclusion: .conclusion, created_at: .created_at, updated_at: .updated_at}'
}

main $*
