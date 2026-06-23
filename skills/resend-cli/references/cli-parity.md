# Official `resend-cli` ↔ bash mapping

Source: https://github.com/resend/resend-cli and https://resend.com/docs/cli (v2.0, 2025).

The official CLI is a strong reference implementation. Two reasons to prefer it over bash for specific tasks:

1. **`webhooks listen`** - opens a local tunnel and pipes webhook events to your machine. Bash can't do this. The skill exposes `resend-webhooks.sh listen` as a thin wrapper.
2. **React Email rendering** - `resend send foo.tsx` renders a JSX template to HTML before sending. Bash can't do this. Use the CLI directly when sending a `.tsx`.

For everything else, the bash scripts are leaner (no separate process, no Node startup time) and easier to integrate into shell pipelines.

## Install

```bash
# Recommended - bun-based, single binary, no Node required
bunx --bun resend-cli@latest --version

# Or via Homebrew
brew install resend/cli/resend

# Or via the install script (curl)
curl -fsSL https://resend.com/install.sh | bash
```

Auth (any of):
```bash
export RESEND_API_KEY=re_xxx                 # env var (shared with bash skill)
bunx --bun resend-cli login                   # stores in OS keychain
bunx --bun resend-cli --api-key re_xxx ...    # one-shot flag
```

## Command-by-command equivalence

| Official CLI                           | Bash equivalent                                | When to prefer the CLI                |
|----------------------------------------|------------------------------------------------|---------------------------------------|
| `resend send foo.tsx`                  | n/a (use CLI)                                  | **always** - renders React Email JSX  |
| `resend send --from --to --subject ...`| `resend-emails.sh send ...`                    | prefer bash unless rendering JSX      |
| `resend batch`                         | `resend-emails.sh batch @emails.json`          | prefer bash                            |
| `resend emails list`                   | `resend-emails.sh ls`                          | prefer bash                            |
| `resend emails get <id>`               | `resend-emails.sh get <id>`                    | prefer bash                            |
| `resend emails cancel <id>`            | `resend-emails.sh cancel <id>`                 | prefer bash                            |
| `resend emails update <id>`            | `resend-emails.sh reschedule <id> <when>`      | prefer bash                            |
| `resend receiving list`                | `resend-received.sh ls`                        | prefer bash                            |
| `resend receiving get <id>`            | `resend-received.sh get <id>`                  | prefer bash                            |
| `resend receiving listen`              | n/a (use CLI)                                  | **CLI only** - local inbox tunnel     |
| `resend receiving forward`             | n/a (use CLI)                                  | **CLI only**                           |
| `resend domains create --name`         | `resend-domains.sh create --name`              | prefer bash                            |
| `resend domains list`                  | `resend-domains.sh ls`                         | prefer bash                            |
| `resend domains get <id>`              | `resend-domains.sh get <id>`                   | prefer bash                            |
| `resend domains verify <id>`           | `resend-domains.sh verify <id>`                | prefer bash                            |
| `resend domains update <id>`           | `resend-domains.sh update <id>`                | prefer bash                            |
| `resend domains delete <id>`           | `resend-domains.sh rm <id>`                    | prefer bash                            |
| `resend api-keys create`               | `resend-api-keys.sh create`                    | prefer bash                            |
| `resend api-keys list`                 | `resend-api-keys.sh ls`                        | prefer bash                            |
| `resend api-keys delete <id>`          | `resend-api-keys.sh rm <id>`                   | prefer bash                            |
| `resend contacts create`               | `resend-contacts.sh create`                    | prefer bash                            |
| `resend contacts list`                 | `resend-contacts.sh ls`                        | prefer bash                            |
| `resend contacts get <id>`             | `resend-contacts.sh get <id>`                  | prefer bash                            |
| `resend contacts update <id>`          | `resend-contacts.sh update <id>`               | prefer bash                            |
| `resend contacts delete <id>`          | `resend-contacts.sh rm <id>`                   | prefer bash                            |
| `resend contacts segments <id>`        | `resend-contacts.sh segments <id>`             | prefer bash                            |
| `resend contacts topics <id>`          | `resend-contacts.sh topics <id>`               | prefer bash                            |
| `resend segments create`               | `resend-segments.sh create`                    | prefer bash                            |
| `resend segments list`                 | `resend-segments.sh ls`                        | prefer bash                            |
| `resend segments get <id>`             | `resend-segments.sh get <id>`                  | prefer bash                            |
| `resend segments contacts <id>`        | `resend-segments.sh contacts <id>`             | prefer bash                            |
| `resend segments delete <id>`          | `resend-segments.sh rm <id>`                   | prefer bash                            |
| `resend topics create`                 | `resend-topics.sh create`                      | prefer bash                            |
| `resend topics list`                   | `resend-topics.sh ls`                          | prefer bash                            |
| `resend topics ...`                    | `resend-topics.sh ...`                         | prefer bash                            |
| `resend broadcasts create`             | `resend-broadcasts.sh create`                  | prefer bash                            |
| `resend broadcasts send <id>`          | `resend-broadcasts.sh send <id>`               | prefer bash                            |
| `resend broadcasts ...`                | `resend-broadcasts.sh ...`                     | prefer bash                            |
| `resend templates create`              | `resend-templates.sh create`                   | prefer bash                            |
| `resend templates publish <id>`        | `resend-templates.sh publish <id>`             | prefer bash                            |
| `resend templates duplicate <id>`      | `resend-templates.sh duplicate <id>`           | prefer bash                            |
| `resend templates ...`                 | `resend-templates.sh ...`                      | prefer bash                            |
| `resend webhooks create`               | `resend-webhooks.sh create`                    | prefer bash                            |
| `resend webhooks listen --port N`      | `resend-webhooks.sh listen --port N`           | **CLI under the hood** - only choice  |
| `resend webhooks list/get/update/delete` | `resend-webhooks.sh ls/get/update/rm`        | prefer bash                            |
| `resend automations create`            | `resend-automations.sh create`                 | **MCP gap - bash works**, fall back to CLI on 404 |
| `resend automations list`              | `resend-automations.sh ls`                     | fall back to CLI on 404                |
| `resend automations get/update/stop/delete <id>` | `resend-automations.sh get/update/stop/rm <id>` | fall back to CLI on 404 |
| `resend events send`                   | `resend-events.sh send`                        | prefer bash                            |
| `resend events create/list/get/update/delete` | `resend-events.sh create/ls/get/update/rm` | fall back to CLI on 404 |
| `resend doctor`                        | `resend-ensure.sh`                             | **bash version is more focused** - Resend-specific live check |
| `resend whoami`                        | `resend-ensure.sh` (prints team + permission tier) | prefer bash                       |
| `resend open`                          | n/a                                            | **CLI only** - opens dashboard URL    |
| `resend update`                        | n/a                                            | **CLI only** - self-update             |
| `resend completion`                    | n/a                                            | **CLI only** - shell completions       |

## Profile switching (multi-team)

The CLI supports `--profile <name>` with profiles stored in `~/.config/resend-cli/profiles.json`. Bash equivalent: one `.env.<team>` per team, `set -a; source .env.acme; set +a` to switch.

```bash
# CLI profile workflow
bunx --bun resend-cli --profile acme send --to a@b.com --subject Hi --html '<p>Hi</p>'
bunx --bun resend-cli --profile staging send ...

# Bash profile workflow
set -a; source .env.acme; set +a
scripts/resend-emails.sh send --to a@b.com --subject Hi --html '<p>Hi</p>'
set -a; source .env.staging; set +a
scripts/resend-emails.sh send ...
```

Both work; bash keeps state in normal env files (greppable, source-controlled per repo via `.env.local`), CLI keeps state in a hidden JSON.
