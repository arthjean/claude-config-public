# `gh` CLI command reference

Compact map of the official `gh` CLI surface - what's first-class, what flags matter, and one-liner examples per command. Use this when you want to drive `gh` directly instead of going through the bash helpers.

Source: https://cli.github.com/manual/

## `gh auth`

```bash
gh auth login                                     # interactive: pick GitHub.com / GHES, browser or token
gh auth login --hostname enterprise.example.com   # GHES instance
gh auth login --with-token < mytoken.txt          # non-interactive: pipe a PAT
gh auth logout
gh auth status                                    # active host, scopes, token (masked)
gh auth token                                     # print active token (use in scripts)
gh auth refresh --scopes write:packages           # add scopes without re-logging
gh auth switch                                    # switch between stored accounts
```

Token resolution order: `GH_TOKEN` env > `GITHUB_TOKEN` env > keyring (set by `gh auth login`).

## `gh repo`

```bash
gh repo create my-repo --public --clone
gh repo create org/repo --private --description "desc" --gitignore Node --license MIT
gh repo clone owner/repo [dir]
gh repo fork owner/repo --clone --remote
gh repo view [owner/repo] --web
gh repo list [owner] --limit 50 --json name,url,isPrivate,stargazerCount
gh repo edit --description "new desc" --visibility private --add-topic rust,cli
gh repo delete owner/repo --yes        # destructive; --yes skips confirmation
gh repo sync                           # pull upstream changes into a fork
gh repo archive owner/repo --yes
gh repo set-default owner/repo         # for ambiguous default-resolution
gh repo rename new-name                # rename current repo
```

## `gh issue`

```bash
gh issue create --title "Bug" --body "desc" --label bug --assignee @me
gh issue list --state open --label "priority:high" --limit 30
gh issue list --json number,title,state,labels,assignees
gh issue view 42 --json title,body,comments
gh issue close 42 --comment "Fixed in #99" --reason completed
gh issue reopen 42
gh issue comment 42 --body "see also #50"
gh issue edit 42 --title "New title" --add-label "enhancement" --remove-label "wontfix"
gh issue transfer 42 owner/other-repo
gh issue lock 42 --reason spam
gh issue unlock 42
gh issue develop 42                    # create a linked branch named after the issue
gh issue pin 42
gh issue status                        # issues assigned to / mentioning / created by me
```

## `gh pr`

```bash
gh pr create --title "feat: thing" --body "desc" --base main --draft --reviewer @octocat,@team
gh pr create --fill                    # auto-fill title/body from commits
gh pr list --state all --limit 20
gh pr list --author "@me" --json number,title,state,headRefName
gh pr view 123 --json title,body,reviews,mergeable,files
gh pr checkout 123                     # local checkout - also works on URLs
gh pr review 123 --approve
gh pr review 123 --request-changes --body "Please fix the tests"
gh pr review 123 --comment --body "LGTM"
gh pr merge 123 --squash --delete-branch
gh pr merge 123 --rebase --auto        # auto-merge when checks pass
gh pr close 123
gh pr reopen 123
gh pr ready 123                        # convert draft → ready
gh pr edit 123 --title "Updated title" --add-label "urgent"
gh pr diff 123
gh pr checks 123 --watch               # live-watch CI
gh pr comment 123 --body "ping @team"
gh pr status                           # active PRs (mine + needing review)
```

## `gh release`

```bash
gh release create v1.2.3 --title "v1.2.3" --notes "changelog" dist/*.tar.gz
gh release create v1.2.3 --generate-notes --prerelease
gh release list --limit 10
gh release view v1.2.3
gh release upload v1.2.3 artifact.tar.gz#"Linux x64"
gh release download v1.2.3 --dir ./dist --pattern "*.tar.gz"
gh release edit v1.2.3 --title "new" --draft=false --prerelease=false
gh release delete v1.2.3 --yes
```

## `gh workflow` / `gh run`

```bash
gh workflow list
gh workflow view ci.yml --yaml
gh workflow run ci.yml --ref main -f env=staging   # workflow_dispatch
gh workflow enable ci.yml
gh workflow disable ci.yml

gh run list --workflow ci.yml --limit 20
gh run list --json conclusion,status,headBranch,databaseId
gh run view 123456                   # summary
gh run view 123456 --log             # all logs (huge - pipe to file)
gh run view 123456 --log-failed      # only failed-step logs
gh run watch 123456
gh run rerun 123456
gh run rerun 123456 --failed         # only failed jobs
gh run cancel 123456
gh run download 123456 --dir ./artifacts
gh run download 123456 --name my-artifact
```

## `gh gist`

```bash
gh gist create file.txt --public --desc "my snippet"
gh gist create *.md --secret
gh gist list --limit 20
gh gist view abc123 --raw
gh gist edit abc123             # opens in $EDITOR
gh gist delete abc123 --yes
gh gist clone abc123
```

## `gh secret` / `gh variable`

```bash
# Repo secrets
gh secret set MY_SECRET                         # interactive prompt
gh secret set MY_SECRET --body "value"
gh secret set MY_SECRET --env production        # environment secret
gh secret set MY_SECRET --org myorg --visibility all       # org secret
gh secret list
gh secret delete MY_SECRET

# Plain variables (not encrypted)
gh variable set MY_VAR --body "value"
gh variable set MY_VAR --env production
gh variable list
gh variable delete MY_VAR
```

## `gh label`

```bash
gh label create "triage" --description "needs triage" --color "FF0000"
gh label list --limit 200
gh label edit "bug" --new-name "defect" --color "AA0000"
gh label delete "wontfix" --yes
gh label clone owner/source-repo                # copy all labels from another repo
```

## `gh project` (Projects v2)

```bash
gh project list --owner org
gh project create --owner org --title "Q3 Roadmap"
gh project view 1 --owner org
gh project item-add 1 --owner org --url https://github.com/org/repo/issues/42
gh project item-list 1 --owner org --format json
gh project item-edit --id ITEM_ID --field-id FIELD_ID --project-id PROJECT_ID --text "value"
gh project item-edit --id ITEM_ID --field-id FIELD_ID --project-id PROJECT_ID --single-select-option-id OPT_ID
gh project field-create 1 --owner org --name "Priority" --data-type TEXT
gh project field-list 1 --owner org
gh project close 1 --owner org
gh project delete 1 --owner org --yes
```

## `gh search`

```bash
gh search repos "topic:rust stars:>1000" --limit 20 --json name,stargazersCount,url
gh search issues "is:open label:bug repo:cli/cli" --limit 30 --json number,title
gh search prs "is:open review-requested:@me" --json number,title,repository
gh search code "useState filename:*.tsx org:facebook" --limit 20
gh search commits "fix crash author:octocat" --repo cli/cli
```

## `gh ruleset`, `gh attestation`, `gh cache`

```bash
gh ruleset list
gh ruleset view 12
gh ruleset check main             # evaluate active rulesets for a branch

gh attestation verify artifact.tar.gz --repo owner/repo
gh attestation download artifact.tar.gz --repo owner/repo

gh cache list
gh cache delete <key>
```

## `gh codespace`

```bash
gh codespace list
gh codespace create --repo owner/repo --branch main --machine basicLinux32gb
gh codespace ssh                                     # interactive picker
gh codespace ssh -c my-codespace -- -L 3000:localhost:3000
gh codespace delete -c my-codespace --yes
gh codespace ports --codespace my-codespace
gh codespace ports forward 3000:3000 -c my-codespace
gh codespace stop -c my-codespace
gh codespace view -c my-codespace --json name,state,gitStatus
```

## `gh extension`

```bash
gh extension install owner/gh-extension
gh extension list
gh extension upgrade --all
gh extension remove gh-extension
gh extension exec gh-extension [args]
```

## `gh api` - the universal escape hatch

```bash
# REST GET (default method)
gh api repos/cli/cli

# REST with method + fields. -f sends string; -F casts to int/bool/null.
gh api repos/{owner}/{repo}/issues --method POST \
  -f title="Bug report" \
  -f body="Steps to reproduce" \
  -f "assignees[]=octocat" \
  -F milestone=3

# {owner}/{repo} is auto-resolved from the current repo's git remote.

# Pagination - auto-follows Link: rel="next" headers and concatenates pages
gh api repos/cli/cli/issues --paginate

# Inline JQ filter
gh api repos/cli/cli/issues --paginate --jq '.[].title'

# Go template formatting
gh api repos/cli/cli --template '{{.full_name}} - {{.description}}'

# Pin API version explicitly
gh api -H "X-GitHub-Api-Version: 2022-11-28" repos/cli/cli

# GraphQL
gh api graphql -f query='
  query($owner:String!, $name:String!) {
    repository(owner:$owner, name:$name) {
      id
      defaultBranchRef { name }
    }
  }' -f owner=cli -f name=cli

# GraphQL with cursor pagination via --paginate (uses pageInfo.endCursor)
gh api graphql --paginate -f query='
  query($endCursor: String) {
    viewer { repositories(first:100, after:$endCursor) {
      nodes { nameWithOwner }
      pageInfo { hasNextPage endCursor }
    }}
  }'
```

## Output / scripting flags

```bash
# --json with field selection (typed commands only)
gh repo list --json name,url,description,isPrivate,stargazerCount
gh pr list --json number,title,state,headRefName,isDraft

# --jq inline filter (requires --json)
gh pr list --json number,title --jq '.[] | select(.title | startswith("[FIX]")) | .number'
gh issue list --json number,labels --jq '.[] | select(.labels[].name == "bug") | .number'

# -q is an alias for --jq
gh pr list --json number,title -q '.[0].number'

# gh api jq on REST responses
gh api repos/cli/cli/issues --paginate --jq '.[].number'
```

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | Generic error (command failed, entity not found, network) |
| `2` | Misuse of the command (bad flags, missing required args) |
| `4` | Authentication error |

Use in scripts:
```bash
gh pr view 999 --json number 2>/dev/null && echo "exists" || echo "not found"
```
