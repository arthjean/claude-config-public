# Claude Config Starter

Configuration publique et personnalisable pour Claude Code: instructions durables, agents spécialisés, skills, règles de documentation, statusline, et settings de base. Le repo sert de point de départ pour construire votre propre `~/.claude` sans repartir d'une page blanche.

## Installation rapide

Clonez le repo, sauvegardez votre configuration actuelle, puis copiez les fichiers dans votre dossier Claude:

```bash
git clone https://github.com/<your-org>/<your-fork>.git claude-config
cp -R ~/.claude ~/.claude.backup.$(date +%Y%m%d-%H%M%S)
rsync -av --exclude ".git" --exclude "README.md" claude-config/ ~/.claude/
```

Sur Windows, utilisez le dossier `%USERPROFILE%\.claude` et copiez les fichiers avec PowerShell:

```powershell
git clone https://github.com/<your-org>/<your-fork>.git claude-config
Copy-Item "$env:USERPROFILE\.claude" "$env:USERPROFILE\.claude.backup" -Recurse -Force
Copy-Item ".\claude-config\*" "$env:USERPROFILE\.claude" -Recurse -Force
```

Ne copiez jamais de secrets dans ce repo: `.env`, `.credentials.json`, tokens, clés SSH, certificats privés, historiques de session, caches, logs, et `settings.local.json` doivent rester locaux.

## Ce que contient le repo

- `CLAUDE.md`: comportement global de Claude Code, template de personnalisation, règles de collaboration, stack par défaut.
- `AGENTS.md`: miroir générique pour environnements compatibles Codex.
- `settings.json`: réglages Claude Code portables.
- `rules/`: règles spécialisées, dont Context7 et Rust.
- `agents/`: agents spécialisés pour docs, exploration de codebase, et recherche web.
- `skills/`: workflows réutilisables avec références et scripts.
- `statusline.sh`: statusline optionnelle pour le TUI.

## Personnalisation

Commencez par `CLAUDE.md`. Remplacez les defaults par votre vrai contexte: ton souhaité, stack, projets actifs, critères de décision, contraintes de sécurité, formats de réponse, règles Git, et habitudes d'orchestration. Gardez les informations personnelles minimales: ce fichier est très utile localement, mais il devient sensible si vous le publiez.

Ensuite, inspectez `settings.json`. Les permissions sont volontairement puissantes, donc adaptez-les à votre niveau de confiance. Gardez `settings.local.json` pour les overrides machine et ne le commitez pas.

## Prompt d'onboarding

Collez ce paragraphe dans Claude Code après avoir cloné le fork:

```text
Installe ce fork comme base de mon `~/.claude` en mode autonome et maximaliste. Comprends l'esprit de la config, garde l'agent proactif, permissif, outillé et orienté action, active ce qui augmente sa puissance (agents, skills, rules, statusline, settings) sans me demander de micro-validations, adapte seulement ce qui dépend de ma machine, de mon stack et de mon style, protège mes secrets et fichiers privés existants, puis applique l'intégration la plus directe possible et résume ce que tu as changé.
```

## Checklist avant publication

Avant de rendre votre fork public:

```bash
git status --short
git ls-files
rg -n -i "token|secret|password|credential|api[_-]?key|private_key|BEGIN .* PRIVATE KEY|/home/|C:\\\\Users|\\.env"
rg -n -i "<your-name>|<your-handle>|<your-company>|<private-project>"
```

Supprimez les états locaux du suivi Git: `teams/`, caches de plugins, sessions, debug logs, shell snapshots, telemetry, file history, prompts, downloads, et tout répertoire généré par l'outil.

## Mise à jour

Gardez votre fork public générique. Mettez vos préférences vraiment personnelles dans une branche privée, un repo privé, ou `settings.local.json`. Le bon modèle: public pour la structure, privé pour l'identité.
