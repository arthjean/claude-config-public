# GitHub REST + GraphQL API reference

When `gh` doesn't have a first-class command, use `gh api <endpoint>` or `scripts/github-api.sh`. Both authenticate with the active token and inherit the configured `X-GitHub-Api-Version`.

Source: https://docs.github.com/en/rest

## `github_api()` boilerplate (already in `scripts/_lib.sh`)

```bash
# Inside any script that sources _lib.sh:
github_api METHOD PATH [json_body | --header "Header: value"]
github_api GET    "/user"
github_api GET    "/repos/cli/cli/issues?per_page=100&state=open"
github_api POST   "/repos/cli/cli/issues" '{"title":"Bug","body":"…"}'
github_api PATCH  "/repos/cli/cli/issues/42" '{"state":"closed"}'
github_api DELETE "/repos/cli/cli/labels/wontfix"

# GraphQL helper
github_graphql 'query($login:String!){user(login:$login){id}}' login=octocat

# Auto-paginate (concatenates JSON arrays across all pages)
github_paginate "/repos/cli/cli/issues?per_page=100&state=all"
```

Headers auto-attached: `Authorization: Bearer $GITHUB_TOKEN`, `Accept: application/vnd.github+json`, `X-GitHub-Api-Version: $GITHUB_API_VERSION`, `User-Agent: github-cli-skill`. `Content-Type: application/json` is added automatically when the body starts with `{`.

Retry behavior: 3 attempts with `Retry-After` / `X-RateLimit-Reset` honored. Refuses to wait > 120s.

## REST endpoint catalog (the gaps `gh` doesn't cover natively)

### Webhooks (repo + org)

```bash
# Repo webhook CRUD
gh api repos/{owner}/{repo}/hooks                                   # list
gh api repos/{owner}/{repo}/hooks --method POST \
  -f name="web" -F active=true \
  -f "events[]=push" -f "events[]=pull_request" \
  -f "config[url]=https://example.com/hook" \
  -f "config[content_type]=json" \
  -f "config[secret]=mysecret"
gh api repos/{owner}/{repo}/hooks/{hook_id} --method PATCH -F active=false
gh api repos/{owner}/{repo}/hooks/{hook_id} --method DELETE
gh api repos/{owner}/{repo}/hooks/{hook_id}/tests --method POST     # send a test event
gh api repos/{owner}/{repo}/hooks/{hook_id}/deliveries              # delivery log
gh api repos/{owner}/{repo}/hooks/{hook_id}/deliveries/{id}/attempts --method POST  # redeliver

# Org webhooks
gh api orgs/{org}/hooks --method POST -f "config[url]=…" -f "events[]=push"
```

### Branch protection / rulesets

```bash
# Modern ruleset API (preferred over the legacy branch-protection endpoints)
gh api repos/{owner}/{repo}/rulesets
gh api repos/{owner}/{repo}/rulesets/{id}
gh api repos/{owner}/{repo}/rulesets --method POST --input ruleset.json
gh api repos/{owner}/{repo}/rulesets/{id} --method DELETE

# Legacy branch protection (still works)
gh api repos/{owner}/{repo}/branches/{branch}/protection --method PUT \
  -F "required_status_checks[strict]=true" \
  -f "required_status_checks[contexts][]=ci/build" \
  -F "enforce_admins=true" \
  -F "required_pull_request_reviews[required_approving_review_count]=1"
```

### Deploy keys

```bash
gh api repos/{owner}/{repo}/keys
gh api repos/{owner}/{repo}/keys --method POST \
  -f title="ci" -f key="ssh-rsa AAAA…" -F read_only=true
gh api repos/{owner}/{repo}/keys/{key_id} --method DELETE
```

### Repo invitations / collaborators

```bash
gh api repos/{owner}/{repo}/invitations
gh api repos/{owner}/{repo}/collaborators
gh api repos/{owner}/{repo}/collaborators/{user} --method PUT \
  -f permission=push                                      # pull|triage|push|maintain|admin
gh api repos/{owner}/{repo}/collaborators/{user} --method DELETE
```

### Topics

```bash
gh api repos/{owner}/{repo}/topics
gh api repos/{owner}/{repo}/topics --method PUT -f "names[]=rust" -f "names[]=cli"
```

### Traffic stats (push-permission required)

```bash
gh api repos/{owner}/{repo}/traffic/views                 # 14-day view counts
gh api repos/{owner}/{repo}/traffic/clones                # 14-day clone counts
gh api repos/{owner}/{repo}/traffic/popular/referrers     # top referrers
gh api repos/{owner}/{repo}/traffic/popular/paths         # top content paths
```

### Actions - beyond what `gh run` exposes

```bash
gh api repos/{owner}/{repo}/actions/runners                       # self-hosted runner inventory
gh api repos/{owner}/{repo}/actions/runners/registration-token --method POST
gh api repos/{owner}/{repo}/actions/cache/usage                   # GB used + storage GiB
gh api orgs/{org}/settings/billing/actions                        # org-level Actions billing
gh api repos/{owner}/{repo}/actions/permissions                   # allowed actions config
gh api repos/{owner}/{repo}/actions/oidc/customization/sub        # OIDC sub claim customization
```

### Org administration

```bash
# Member admin
gh api orgs/{org}/members --paginate --jq '.[].login'
gh api orgs/{org}/memberships/{user} --method PUT -f role=admin   # admin | member
gh api orgs/{org}/members/{user} --method DELETE
gh api orgs/{org}/outside_collaborators
gh api orgs/{org}/outside_collaborators/{user} --method PUT       # convert member → outside
gh api orgs/{org}/outside_collaborators/{user} --method DELETE

# Pending invitations
gh api orgs/{org}/invitations
gh api orgs/{org}/invitations --method POST -f email="x@y.com" -f role=direct_member
gh api orgs/{org}/invitations/{id} --method DELETE                # cancel

# Teams (also wrapped by github-orgs.sh)
gh api orgs/{org}/teams
gh api orgs/{org}/teams --method POST -f name="backend" -f privacy=closed
gh api orgs/{org}/teams/{slug}/members
gh api orgs/{org}/teams/{slug}/memberships/{user} --method PUT -f role=maintainer
gh api orgs/{org}/teams/{slug}/repos/{owner}/{repo} --method PUT -f permission=push
```

### Notifications

```bash
gh api notifications                                              # inbox
gh api notifications --method PUT -f last_read_at="$(date -u +%FT%TZ)"   # mark all read
gh api notifications/threads/{id}                                 # single thread
gh api notifications/threads/{id} --method PATCH                  # mark read
gh api notifications/threads/{id} --method DELETE                 # mark done (dismiss)
gh api notifications/threads/{id}/subscription --method PUT \
  -F subscribed=true -F ignored=false
```

### Stars

```bash
gh api user/starred --paginate --jq '.[].full_name'
gh api user/starred/{owner}/{repo} --method PUT                   # star (Content-Length: 0)
gh api user/starred/{owner}/{repo} --method DELETE                # unstar
```

### User identity / keys

```bash
gh api user
gh api user/emails
gh api user/keys
gh api user/keys --method POST -f title="laptop" -f key="ssh-ed25519 …"
gh api user/keys/{id} --method DELETE
gh api user/gpg_keys
gh api users/{username}                                           # public profile of any user
```

### Codespaces secrets / Dependabot secrets

```bash
gh api user/codespaces/secrets                                    # personal codespaces secrets
gh api repos/{owner}/{repo}/codespaces/secrets                    # repo-scoped
gh api repos/{owner}/{repo}/dependabot/secrets                    # used by Dependabot updates
```

### Vulnerability alerts toggle

```bash
gh api repos/{owner}/{repo}/vulnerability-alerts --method PUT     # enable
gh api repos/{owner}/{repo}/vulnerability-alerts --method DELETE  # disable
gh api repos/{owner}/{repo}/automated-security-fixes --method PUT # enable Dependabot security fixes
```

### License / language stats

```bash
gh api repos/{owner}/{repo}/license --jq '.license.spdx_id'
gh api repos/{owner}/{repo}/languages
```

### Autolinks (custom JIRA-style references)

```bash
gh api repos/{owner}/{repo}/autolinks --method POST \
  -f key_prefix="JIRA-" -f url_template="https://jira.example.com/browse/JIRA-<num>"
gh api repos/{owner}/{repo}/autolinks
gh api repos/{owner}/{repo}/autolinks/{id} --method DELETE
```

### Rate limit

```bash
gh api rate_limit --jq '.resources | {core: .core, graphql: .graphql, search: .search}'
```

## GraphQL - what you only get via `gh api graphql`

Some operations have no REST equivalent:

### Resolve / unresolve a PR review thread

```bash
gh api graphql -f query='
mutation($id:ID!){ resolveReviewThread(input:{threadId:$id}){ thread{ isResolved } } }' \
  -f id=PRRT_kwDO…
```

### Convert PR draft ↔ ready (also wrapped by `github-prs.sh ready/draft`)

```bash
gh api graphql -f query='
mutation($id:ID!){ markPullRequestReadyForReview(input:{pullRequestId:$id}){ pullRequest{ isDraft } } }' \
  -f id=PR_kwDO…

gh api graphql -f query='
mutation($id:ID!){ convertPullRequestToDraft(input:{pullRequestId:$id}){ pullRequest{ isDraft } } }' \
  -f id=PR_kwDO…
```

### Create / comment on Discussions (MCP gap)

```bash
# Create a discussion
gh api graphql -f query='
mutation($repo:ID!,$cat:ID!,$title:String!,$body:String!){
  createDiscussion(input:{repositoryId:$repo,categoryId:$cat,title:$title,body:$body}){
    discussion{ id url }
  }
}' -f repo=R_kgDO… -f cat=DIC_kwDO… -f title="Help" -f body="Question…"

# Add a comment
gh api graphql -f query='
mutation($id:ID!,$body:String!){
  addDiscussionComment(input:{discussionId:$id,body:$body}){ comment{ id } }
}' -f id=D_kwDO… -f body="Reply…"
```

### Projects v2 mutations (also wrapped by `github-projects.sh`)

See [scripts/github-projects.sh](../scripts/github-projects.sh) for the full set of typed wrappers (add/remove items, set field values, post status updates).

## Pagination patterns

### REST - Link headers

```bash
# In a script:
source "$(dirname "$0")/_lib.sh"
all=$(github_paginate "/repos/cli/cli/issues?per_page=100&state=all")
echo "$all" | jq 'length'

# Via gh:
gh api repos/cli/cli/issues --paginate --jq '.[].number'
```

### GraphQL - cursor

```bash
gh api graphql --paginate -f query='
query($endCursor: String) {
  viewer {
    repositories(first: 100, after: $endCursor) {
      nodes { nameWithOwner }
      pageInfo { hasNextPage endCursor }
    }
  }
}' --jq '.data.viewer.repositories.nodes[].nameWithOwner'
```

`--paginate` requires the query to declare `$endCursor: String` and use it in `after:`, plus return `pageInfo { endCursor hasNextPage }`. `gh` handles the loop.

## Rate-limit handling

Authenticated REST limits:
- **Core**: 5,000 req/hour (GitHub.com Free), 15,000/hour (Team), 15,000/hour per installation (Apps).
- **GraphQL**: 5,000 points/hour. Each query has a calculated point cost.
- **Search**: 30 req/min.
- **Secondary**: triggered by burst behavior (concurrent requests, content creation > 80/min).

Inspect:
```bash
gh api rate_limit --jq '.resources'
```

The `github_api` helper detects:
- `429` (primary) → reads `Retry-After` (seconds), sleeps, retries up to 3×.
- `403 + retry-after` (secondary) → same.
- `403 + x-ratelimit-remaining: 0` → reads `x-ratelimit-reset` epoch, computes wait.
- Refuses to wait > 120s - surfaces an error so you can split the workload instead.

## Common gotchas

1. **Path placeholders**: `gh api repos/{owner}/{repo}/…` auto-resolves from the current git remote. From outside a repo, write the literal path: `gh api repos/cli/cli/…`.
2. **Body fields**: `-f` sends strings, `-F` casts to numbers/bools/null. For arrays, use `-f "key[]=val1" -f "key[]=val2"`. For nested objects, use `-f "config[url]=…"`.
3. **Headers**: pass with `-H "Header: value"`. Most-needed: `-H "Accept: application/vnd.github+json"` (default), `-H "X-GitHub-Api-Version: 2022-11-28"`, `-H "Accept: application/vnd.github.raw"` (raw file content).
4. **Empty PUT body**: GitHub's `star_repository` and similar idempotent PUTs require `Content-Length: 0`. `gh api … --method PUT` handles this automatically; `curl` needs `-H "Content-Length: 0"` and `-d ''`.
5. **Time format**: ISO 8601 in UTC, e.g. `2026-05-05T12:00:00Z`. The `notifications` and `traffic` endpoints also accept `since=YYYY-MM-DDTHH:MM:SSZ`.
6. **404 vs 403**: GitHub returns `404` (not `403`) when a token lacks read access to a private resource - to avoid leaking existence. If you're sure something exists, check token scopes and repo permissions, not just the URL.
7. **Conditional requests**: `gh api … -H "If-None-Match: \"$etag\""` returns `304` and doesn't count against your rate limit. Useful for polling.

## GHES / GitHub Enterprise

Set `GITHUB_API_BASE` to your GHES instance:
```bash
export GITHUB_API_BASE="https://ghes.mycompany.com/api/v3"
export GITHUB_HOST="ghes.mycompany.com"      # for gh CLI
gh auth login --hostname ghes.mycompany.com
```

All scripts in this skill respect `GITHUB_API_BASE` (read in `_lib.sh`).
