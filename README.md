# Claude Config Starter

> Version française: [README.fr.md](README.fr.md)

Public, customizable configuration for Claude Code: durable instructions, specialized agents, skills, documentation rules, statusline, and base settings. This repo is a starting point for building your own `~/.claude` without starting from a blank page.

## Quick install

Clone the repo, back up your current configuration, then copy the files into your Claude directory:

```bash
git clone https://github.com/<your-org>/<your-fork>.git claude-config
cp -R ~/.claude ~/.claude.backup.$(date +%Y%m%d-%H%M%S)
rsync -av --exclude ".git" --exclude "README.md" --exclude "README.fr.md" claude-config/ ~/.claude/
```

On Windows, use the `%USERPROFILE%\.claude` directory and copy the files with PowerShell:

```powershell
git clone https://github.com/<your-org>/<your-fork>.git claude-config
Copy-Item "$env:USERPROFILE\.claude" "$env:USERPROFILE\.claude.backup" -Recurse -Force
Copy-Item ".\claude-config\*" "$env:USERPROFILE\.claude" -Recurse -Force
```

Never copy secrets into this repo: `.env`, `.credentials.json`, tokens, SSH keys, private certificates, session history, caches, logs, and `settings.local.json` must stay local.

## What the repo contains

- `CLAUDE.md`: concise global Claude Code map and always-on behavior.
- `AGENTS.md`: concise mirror for Codex-compatible environments.
- `docs/`: progressively disclosed context, engineering, design, research, delivery, and harness guidance.
- `settings.json`: portable Claude Code settings.
- `rules/`: specialized rules, including Context7 and Rust.
- `agents/`: specialized agents for docs, codebase exploration, and web research.
- `skills/`: reusable workflows with references and scripts. These are vendored snapshots: the maintainer's private config symlinks them from an external store, while the public repo embeds them as real files to stay self-contained.
- `scripts/check-guidance.sh`: validates map size, metadata, links, and forbidden em dash glyphs.
- `statusline.sh`: optional statusline for the TUI.

## Customization

Start with `docs/user-context.md` in a private fork or local installation. Add only the stable context that materially improves decisions: positioning, project hierarchy, current focus, collaboration constraints, and writing voice.

Keep `CLAUDE.md` and `AGENTS.md` concise. Detailed or task-specific guidance belongs in the corresponding document, rule, or skill. Do not import every document into `CLAUDE.md`: Claude Code expands imports into startup context.

Then inspect `settings.json`. The permissions are intentionally powerful, so adapt them to your own trust level. Keep `settings.local.json` for machine-local overrides and never commit it.

## Onboarding prompt

Paste this paragraph into Claude Code after cloning your fork:

```text
Install this fork as the base of my `~/.claude` in autonomous, maximalist mode. Understand the spirit of the config, keep the agent proactive, permissive, well-tooled and action-oriented, enable everything that increases its power (agents, skills, rules, statusline, settings) without asking me for micro-validations, adapt only what depends on my machine, my stack and my style, protect my existing secrets and private files, then apply the most direct integration possible and summarize what you changed.
```

## Update prompt

For the repo maintainer: whenever the private config evolves, paste this prompt into Claude Code to resync the public repo.

```text
Update the public claude-config-public repo from my private config. Sources of truth: ~/.claude for settings.json, statusline.sh, rules/, agents/, CLAUDE.md, docs/, scripts/ and the repo-specific skills, and ~/.agents/skills for the symlinked skills. Vendor the symlinked skills as real files, remove from the public repo any skills dropped from the private config, and port over changes while keeping their generic form: no persona or private context, no name, handle, email, company or personal project, no absolute user paths, no distro-specific install commands, no model pin tied to my subscription, and placeholders for example keys or tokens. Update both READMEs and .gitignore when the structure changes. Run the guidance and publication checks, fix every detected leak, then make atomic Conventional Commits and push.
```

## Pre-publication checklist

Before making your fork public:

```bash
./scripts/check-guidance.sh
git status --short
git ls-files
rg -n -i "token|secret|password|credential|api[_-]?key|private_key|BEGIN .* PRIVATE KEY|/home/|C:\\\\Users|\\.env"
rg -n -i "<your-name>|<your-handle>|<your-company>|<private-project>"
```

Remove local state from Git tracking: `teams/`, plugin caches, sessions, debug logs, shell snapshots, telemetry, file history, prompts, downloads, and any tool-generated directory.

## Keeping it updated

Keep your public fork generic. Put your truly personal preferences in a private branch, a private repo, or `settings.local.json`. The right model: public for structure, private for identity.
