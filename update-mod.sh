#!/usr/bin/env bash
set -euo pipefail

branch=$1
version_bump=$2
target_repo=$3

git clone https://$GITHUB_TOKEN@"$target_repo".git target_repo
cd target_repo
git checkout $branch

github_server=$(echo $target_repo | cut -d"/" -f1)
target_repo_short=${target_repo#*$github_server/}
echo "Target repo is $target_repo_short."

git config user.name github-actions
git config user.email github-actions@github.com
git config --global url."https://$GITHUB_TOKEN:x-oauth-basic@github.com/".insteadOf "https://github.com/"
git checkout -b update-"$GITHUB_REPOSITORY"-"$branch"-"$VERSION"-"$(date +%s)"

go get github.com/"$GITHUB_REPOSITORY"@"$version_bump"
go mod tidy
rm -rf vendor
go mod vendor

if [ -n "$(git status --untracked-files=no --porcelain)" ]; then
  git add .
  git commit -m "Updating $GITHUB_REPOSITORY deps"
  command=$(hub pull-request -m "Update version of $GITHUB_REPOSITORY." -b "$target_repo_short:$branch" \
  -h "$target_repo_short:update-$GITHUB_REPOSITORY-$VERSION-$(date +%s)" \
  -l "plugin-update" -a "$ACTOR" -p | tail -1) || return 1
  echo "$command"
  text="<$command|PR on Vault $branch> successfully created! ($GITHUB_REPOSITORY version: $VERSION) and assigned to $ACTOR"
else
  text="No PR created on Vault $branch ($GITHUB_REPOSITORY version: $VERSION) as this module version bump does not result in an update to go.mod. Please double check."
fi

json='
{
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "'$text'"
      }
    }
  ]
}'

echo "$json" | curl -X POST -H "Content-type: application/json; charset=utf-8" \
--data @- \
"$SLACK_WEBHOOK_URL";
