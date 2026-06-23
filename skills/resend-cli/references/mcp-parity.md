# resend-mcp ↔ bash command mapping

The official `resend/resend-mcp` server exposes ~50 tools across 11 resource groups. This skill covers every one of them **and** exposes four resource groups the MCP doesn't: **automations**, **events/event-schemas**, **logs**, and **email attachment retrieval**.

Format: bolded rows = MCP gap, this skill covers it.

## Emails

| MCP tool                  | bash equivalent                                       | Notes                                |
|---------------------------|-------------------------------------------------------|--------------------------------------|
| `send_email`              | `resend-emails.sh send --to ... --subject ... --html`  | `--idempotency-key` supported        |
| `batch_send_emails`       | `resend-emails.sh batch @emails.json`                  | max 100, no attachments, no scheduled_at |
| `list_emails`             | `resend-emails.sh ls`                                  | follows `has_more` automatically     |
| `get_email`               | `resend-emails.sh get <id>`                            |                                      |
| `update_email`            | `resend-emails.sh reschedule <id> <new_scheduled_at>`  | PATCH `/emails/{id}`                 |
| `cancel_email`            | `resend-emails.sh cancel <id>`                         | scheduled emails only                |
| **(MCP gap)**             | **`resend-emails.sh attachments <id>`**                | list a sent email's attachments      |
| **(MCP gap)**             | **`resend-emails.sh attachment <eid> <aid>`**          | get a single sent-email attachment   |

## Received emails (inbound)

| MCP tool                          | bash equivalent                                          |
|-----------------------------------|----------------------------------------------------------|
| `list_received_emails`            | `resend-received.sh ls`                                  |
| `get_received_email`              | `resend-received.sh get <id>`                            |
| `list_received_attachments`       | `resend-received.sh attachments <eid>`                   |
| `download_received_attachment`    | `resend-received.sh attachment <eid> <aid> --out file`   |

## Contacts

| MCP tool                          | bash equivalent                                          |
|-----------------------------------|----------------------------------------------------------|
| `create_contact`                  | `resend-contacts.sh create --email ...`                  |
| `list_contacts`                   | `resend-contacts.sh ls`                                  |
| `get_contact`                     | `resend-contacts.sh get <id>`                            |
| `update_contact`                  | `resend-contacts.sh update <id> [flags]`                 |
| `remove_contact`                  | `resend-contacts.sh rm <id>`                             |
| `add_contact_to_segment`          | `resend-contacts.sh add-segment <cid> <seg_id>`          |
| `remove_contact_from_segment`     | `resend-contacts.sh rm-segment <cid> <seg_id>`           |
| `list_contact_segments`           | `resend-contacts.sh segments <cid>`                      |
| `list_contact_topics`             | `resend-contacts.sh topics <cid>`                        |
| `update_contact_topics`           | `resend-contacts.sh set-topics <cid> @subs.json`         |

## Contact properties

| MCP tool                          | bash equivalent                                          |
|-----------------------------------|----------------------------------------------------------|
| `create_contact_property`         | `resend-contact-properties.sh create --name --type`      |
| `list_contact_properties`         | `resend-contact-properties.sh ls`                        |
| `get_contact_property`            | `resend-contact-properties.sh get <id>`                  |
| `update_contact_property`         | `resend-contact-properties.sh update <id>`               |
| `remove_contact_property`         | `resend-contact-properties.sh rm <id>`                   |

## Segments

| MCP tool                          | bash equivalent                                          |
|-----------------------------------|----------------------------------------------------------|
| `create_segment`                  | `resend-segments.sh create --name [--filter]`            |
| `list_segments`                   | `resend-segments.sh ls`                                  |
| `get_segment`                     | `resend-segments.sh get <id>`                            |
| `list_segment_contacts`           | `resend-segments.sh contacts <id>`                       |
| `remove_segment`                  | `resend-segments.sh rm <id>`                             |

## Topics

| MCP tool          | bash equivalent                              |
|-------------------|----------------------------------------------|
| `create_topic`    | `resend-topics.sh create --name`              |
| `list_topics`     | `resend-topics.sh ls`                         |
| `get_topic`       | `resend-topics.sh get <id>`                   |
| `update_topic`    | `resend-topics.sh update <id>`                |
| `remove_topic`    | `resend-topics.sh rm <id>`                    |

## Broadcasts

| MCP tool             | bash equivalent                                  |
|----------------------|--------------------------------------------------|
| `create_broadcast`   | `resend-broadcasts.sh create --subject --html`   |
| `list_broadcasts`    | `resend-broadcasts.sh ls`                         |
| `get_broadcast`      | `resend-broadcasts.sh get <id>`                   |
| `update_broadcast`   | `resend-broadcasts.sh update <id>`                |
| `send_broadcast`     | `resend-broadcasts.sh send <id> [--scheduled-at]` |
| `remove_broadcast`   | `resend-broadcasts.sh rm <id>`                    |

## Templates

| MCP tool              | bash equivalent                                |
|-----------------------|------------------------------------------------|
| `create_template`     | `resend-templates.sh create --name --subject`  |
| `list_templates`      | `resend-templates.sh ls`                        |
| `get_template`        | `resend-templates.sh get <id>`                  |
| `update_template`     | `resend-templates.sh update <id>`               |
| `publish_template`    | `resend-templates.sh publish <id>`              |
| `duplicate_template`  | `resend-templates.sh duplicate <id>`            |
| `remove_template`     | `resend-templates.sh rm <id>`                   |

## Domains

| MCP tool             | bash equivalent                                  |
|----------------------|--------------------------------------------------|
| `create_domain`      | `resend-domains.sh create --name`                |
| `list_domains`       | `resend-domains.sh ls`                            |
| `get_domain`         | `resend-domains.sh get <id>`                      |
| `update_domain`      | `resend-domains.sh update <id>`                   |
| `verify_domain`      | `resend-domains.sh verify <id>`                   |
| `remove_domain`      | `resend-domains.sh rm <id>`                       |
| *(plus convenience)* | `resend-domains.sh dns <id>` - DNS records only   |

## API keys

| MCP tool             | bash equivalent                                                              |
|----------------------|------------------------------------------------------------------------------|
| `create_api_key`     | `resend-api-keys.sh create --name --permission [--domain]`                   |
| `list_api_keys`      | `resend-api-keys.sh ls`                                                       |
| `remove_api_key`     | `resend-api-keys.sh rm <id>`                                                  |

## Webhooks

| MCP tool             | bash equivalent                                                              |
|----------------------|------------------------------------------------------------------------------|
| `create_webhook`     | `resend-webhooks.sh create --url --events email.delivered,email.bounced`     |
| `list_webhooks`      | `resend-webhooks.sh ls`                                                       |
| `get_webhook`        | `resend-webhooks.sh get <id>`                                                 |
| `update_webhook`     | `resend-webhooks.sh update <id>`                                              |
| `remove_webhook`     | `resend-webhooks.sh rm <id>`                                                  |
| *(plus tunnel)*      | `resend-webhooks.sh listen [--port N]` - delegates to `bunx resend-cli`       |

## Automations *(entirely MCP gap - exposed only by this skill and `bunx resend-cli`)*

| Capability                | bash equivalent                                          |
|---------------------------|----------------------------------------------------------|
| Create an automation      | **`resend-automations.sh create --name --trigger`**      |
| List automations          | **`resend-automations.sh ls`**                            |
| Get one                   | **`resend-automations.sh get <id>`**                      |
| Update                    | **`resend-automations.sh update <id> @def.json`**         |
| Stop a running automation | **`resend-automations.sh stop <id>`**                     |
| Delete                    | **`resend-automations.sh rm <id>`**                       |

## Events / event schemas *(entirely MCP gap)*

| Capability                            | bash equivalent                                          |
|---------------------------------------|----------------------------------------------------------|
| Trigger an automation event           | **`resend-events.sh send --event --email --payload`**     |
| Create event schema                   | **`resend-events.sh create --name [--body @schema]`**     |
| List event schemas                    | **`resend-events.sh ls`**                                  |
| Get / Update / Delete                 | **`resend-events.sh get|update|rm <id>`**                  |

## Logs *(entirely MCP gap)*

| Capability                   | bash equivalent                                                   |
|------------------------------|-------------------------------------------------------------------|
| List API request logs        | **`resend-logs.sh ls [--status 422] [--method POST] [--path ...]`** |
| Get one log entry            | **`resend-logs.sh get <log_id>`**                                  |

## Summary

- Every documented `resend-mcp` tool has a 1:1 bash counterpart.
- This skill **exceeds** MCP coverage with 4 resource groups: automations, events/event-schemas, logs, and sent-email attachment retrieval.
- For tunnels and React Email `.tsx` rendering, the bash skill defers to `bunx resend-cli` rather than reinventing it.
