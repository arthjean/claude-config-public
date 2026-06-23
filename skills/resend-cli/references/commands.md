# resend-cli - command index

Every bash subcommand exposed by this skill, grouped by resource. For full flag descriptions, run any script with no args (it prints its usage).

## Preflight

| Script                        | Purpose                                                                              |
|-------------------------------|--------------------------------------------------------------------------------------|
| `scripts/resend-ensure.sh`    | Verify bun/jq/curl + RESEND_API_KEY + live `GET /domains` + permission-tier probe    |

## Raw REST

| Script                  | Usage                                                                              |
|-------------------------|------------------------------------------------------------------------------------|
| `scripts/resend-api.sh` | `METHOD PATH [json_body]` - generic curl with auto auth + UA + 429 retry            |

## Emails

| Subcommand     | Args                                                                                          |
|----------------|-----------------------------------------------------------------------------------------------|
| `send`         | `--from --to --subject --html|--text [--cc --bcc --reply-to --scheduled-at --idempotency-key --tag k=v --attach path --header K=V --topic id]` |
| `batch`        | `<@file.json|json-array>` (≤100, no attachments, no scheduled_at)                              |
| `ls`           | `[--limit N]`                                                                                 |
| `get`          | `<email_id>`                                                                                  |
| `cancel`       | `<email_id>` (scheduled emails)                                                               |
| `reschedule`   | `<email_id> <new_scheduled_at>`                                                               |
| `attachments`  | `<email_id>` *(MCP gap)*                                                                      |
| `attachment`   | `<email_id> <attachment_id>` *(MCP gap)*                                                      |

## Received emails (inbound)

| Subcommand     | Args                                                                |
|----------------|---------------------------------------------------------------------|
| `ls`           | `[--limit N]`                                                       |
| `get`          | `<received_email_id>`                                               |
| `attachments`  | `<received_email_id>`                                               |
| `attachment`   | `<received_email_id> <attachment_id> [--out path]`                  |

## Domains

| Subcommand | Args                                                                                  |
|------------|---------------------------------------------------------------------------------------|
| `create`   | `--name <domain> [--region us-east-1|eu-west-1|sa-east-1|ap-northeast-1] [--click-tracking on|off] [--open-tracking on|off]` |
| `ls`       |                                                                                       |
| `get`      | `<domain_id>`                                                                         |
| `update`   | `<domain_id> [--click-tracking ...] [--open-tracking ...] [--tls ...]`                |
| `verify`   | `<domain_id>`                                                                         |
| `rm`       | `<domain_id>`                                                                         |
| `dns`      | `<domain_id>` - prints just the DNS records to add                                    |

## API keys

| Subcommand | Args                                                                          |
|------------|-------------------------------------------------------------------------------|
| `create`   | `--name <label> --permission full_access|sending_access [--domain <dom_id>]`  |
| `ls`       |                                                                               |
| `rm`       | `<key_id>`                                                                    |

## Contacts

| Subcommand     | Args                                                                                  |
|----------------|---------------------------------------------------------------------------------------|
| `create`       | `--email <a@b.com> [--first --last --unsubscribed --prop k=v ...]`                    |
| `ls`           | `[--limit N]`                                                                         |
| `get`          | `<contact_id>`                                                                        |
| `update`       | `<contact_id> [--email --first --last --unsubscribed true|false --prop k=v ...]`      |
| `rm`           | `<contact_id>`                                                                        |
| `segments`     | `<contact_id>`                                                                        |
| `add-segment`  | `<contact_id> <segment_id>`                                                            |
| `rm-segment`   | `<contact_id> <segment_id>`                                                            |
| `topics`       | `<contact_id>`                                                                        |
| `set-topics`   | `<contact_id> <@file.json|json-body>`                                                  |

## Contact properties

| Subcommand | Args                                                                          |
|------------|-------------------------------------------------------------------------------|
| `create`   | `--name <key> --type string|number|boolean|date [--description ...]`          |
| `ls`       |                                                                               |
| `get`      | `<property_id>`                                                               |
| `update`   | `<property_id> [--name --description]`                                        |
| `rm`       | `<property_id>`                                                               |

## Segments

| Subcommand  | Args                                                          |
|-------------|---------------------------------------------------------------|
| `create`    | `--name [--description --filter @file.json|json]`              |
| `ls`        |                                                               |
| `get`       | `<segment_id>`                                                |
| `contacts`  | `<segment_id> [--limit N]`                                    |
| `rm`        | `<segment_id>`                                                |

## Topics

| Subcommand | Args                                                          |
|------------|---------------------------------------------------------------|
| `create`   | `--name [--description --default-subscribed]`                 |
| `ls`       |                                                               |
| `get`      | `<topic_id>`                                                  |
| `update`   | `<topic_id> [--name --description]`                           |
| `rm`       | `<topic_id>`                                                  |

## Broadcasts

| Subcommand | Args                                                                                                      |
|------------|-----------------------------------------------------------------------------------------------------------|
| `create`   | `--from --subject --html @body.html|--text @body.txt [--name --reply-to --segment <id> --template <id>]`  |
| `ls`       |                                                                                                           |
| `get`      | `<broadcast_id>`                                                                                          |
| `update`   | `<broadcast_id> [--subject --html --text --name --reply-to --from]`                                       |
| `send`     | `<broadcast_id> [--scheduled-at <when>]`                                                                  |
| `rm`       | `<broadcast_id>`                                                                                          |

## Templates

| Subcommand    | Args                                                                                                 |
|---------------|------------------------------------------------------------------------------------------------------|
| `create`      | `--name --subject --html @body.html|--text @body.txt [--from --reply-to --description]`              |
| `ls`          |                                                                                                      |
| `get`         | `<template_id>`                                                                                      |
| `update`      | `<template_id> [--name --subject --html --text --from --reply-to --description]`                     |
| `publish`     | `<template_id>`                                                                                      |
| `duplicate`   | `<template_id> [--name <new_name>]`                                                                  |
| `rm`          | `<template_id>`                                                                                      |

## Webhooks

| Subcommand | Args                                                                                                       |
|------------|------------------------------------------------------------------------------------------------------------|
| `create`   | `--url <https://...> --events evt,evt,... [--name --enabled true|false]`                                    |
| `ls`       |                                                                                                            |
| `get`      | `<webhook_id>`                                                                                             |
| `update`   | `<webhook_id> [--url --events --name --enabled]`                                                            |
| `rm`       | `<webhook_id>`                                                                                             |
| `listen`   | `[--port N ...]` - delegates to `bunx resend-cli webhooks listen` for the local tunnel                      |

## Automations *(MCP gap)*

| Subcommand | Args                                                                |
|------------|---------------------------------------------------------------------|
| `create`   | `--name <name> --trigger <event> [--body @def.json]`                |
| `ls`       |                                                                     |
| `get`      | `<automation_id>`                                                   |
| `update`   | `<automation_id> <@file.json|json-body>`                            |
| `stop`     | `<automation_id>`                                                   |
| `rm`       | `<automation_id>`                                                   |

## Events *(MCP gap)*

| Subcommand | Args                                                                                  |
|------------|---------------------------------------------------------------------------------------|
| `send`     | `--event <name> (--contact <id> | --email <addr>) [--payload @json|json]`             |
| `create`   | `--name <event_name> [--body @schema.json]` *(event schema CRUD)*                     |
| `ls`       |                                                                                       |
| `get`      | `<event_schema_id>`                                                                   |
| `update`   | `<event_schema_id> <@file.json|json-body>`                                            |
| `rm`       | `<event_schema_id>`                                                                   |

## Logs *(MCP gap)*

| Subcommand | Args                                                                                  |
|------------|---------------------------------------------------------------------------------------|
| `ls`       | `[--limit N --method GET|POST|... --status <code> --path <substring>]`                |
| `get`      | `<log_id>`                                                                            |

## Cheat sheet - common one-liners

```bash
# Hello world (auto-loads RESEND_API_KEY from .env.local)
scripts/resend-emails.sh send --from 'Acme <hi@acme.com>' --to me@dev.com --subject Hi --html '<p>Hi</p>'

# Idempotent transactional send
scripts/resend-emails.sh send --to user@x.com --subject Welcome --html @welcome.html --idempotency-key signup-42

# Broadcast to a segment
scripts/resend-segments.sh create --name VIPs --filter @vips.json | jq -r .id
scripts/resend-broadcasts.sh create --from 'Acme <hi@acme.com>' --subject "Launch" --html @launch.html --segment seg_abc
scripts/resend-broadcasts.sh send <broadcast_id>

# Add and verify a domain
scripts/resend-domains.sh create --name acme.com --region eu-west-1
scripts/resend-domains.sh dns <domain_id>     # shows DNS records to add
scripts/resend-domains.sh verify <domain_id>  # after DNS is propagated

# Trigger an automation
scripts/resend-events.sh send --event user.created --email a@b.com --payload '{"plan":"pro"}'

# Debug a 422
scripts/resend-logs.sh ls --status 422 --limit 20

# All emails sent in the last few pages
scripts/resend-emails.sh ls --limit 100 | jq -c 'select(.created_at >= "2026-05-01")'
```
