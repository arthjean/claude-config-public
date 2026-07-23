# Claude Config Starter

> English version: [README.md](README.md)

Configuration publique et personnalisable pour Claude Code: instructions durables, agents spécialisés, skills, règles de documentation, statusline, et settings de base. Le repo sert de point de départ pour construire votre propre `~/.claude` sans repartir d'une page blanche.

## Installation rapide

Clonez le repo, sauvegardez votre configuration actuelle, puis copiez les fichiers dans votre dossier Claude:

```bash
git clone https://github.com/<your-org>/<your-fork>.git claude-config
cp -R ~/.claude ~/.claude.backup.$(date +%Y%m%d-%H%M%S)
rsync -av --exclude ".git" --exclude "README.md" --exclude "README.fr.md" claude-config/ ~/.claude/
```

Sur Windows, utilisez le dossier `%USERPROFILE%\.claude` et copiez les fichiers avec PowerShell:

```powershell
git clone https://github.com/<your-org>/<your-fork>.git claude-config
Copy-Item "$env:USERPROFILE\.claude" "$env:USERPROFILE\.claude.backup" -Recurse -Force
Copy-Item ".\claude-config\*" "$env:USERPROFILE\.claude" -Recurse -Force
```

Ne copiez jamais de secrets dans ce repo: `.env`, `.credentials.json`, tokens, clés SSH, certificats privés, historiques de session, caches, logs, et `settings.local.json` doivent rester locaux.

## Ce que contient le repo

- `CLAUDE.md`: carte globale concise et comportement toujours chargé de Claude Code.
- `AGENTS.md`: miroir concis pour les environnements compatibles Codex.
- `docs/`: contexte, engineering, design, recherche, livraison et harness chargés progressivement.
- `settings.json`: réglages Claude Code portables.
- `rules/`: règles spécialisées, dont Context7 et Rust.
- `agents/`: agents spécialisés pour docs, exploration de codebase, et recherche web.
- `skills/`: workflows réutilisables avec références et scripts. Ce sont des snapshots vendorés: la config privée du mainteneur les symlinke depuis un store externe, le repo public les embarque en vrais fichiers pour rester autonome.
- `scripts/check-guidance.sh`: contrôle la taille des cartes, les métadonnées, les liens et les tirets cadratins interdits.
- `statusline.sh`: statusline optionnelle pour le TUI.

## Personnalisation

Commencez par `docs/user-context.md` dans un fork privé ou une installation locale. Ajoutez uniquement le contexte stable qui améliore réellement les décisions: positionnement, hiérarchie des projets, focus actuel, contraintes de collaboration et voix rédactionnelle.

Gardez `CLAUDE.md` et `AGENTS.md` concis. Les règles détaillées ou occasionnelles appartiennent au document, à la rule ou au skill correspondant. N'importez pas tous les documents dans `CLAUDE.md`: Claude Code développe les imports dans le contexte de démarrage.

Ensuite, inspectez `settings.json`. Les permissions sont volontairement puissantes, donc adaptez-les à votre niveau de confiance. Gardez `settings.local.json` pour les overrides machine et ne le commitez pas.

## Prompt d'onboarding

Collez ce paragraphe dans Claude Code après avoir cloné le fork:

```text
Installe ce fork comme base de mon `~/.claude` en mode autonome et maximaliste. Comprends l'esprit de la config, garde l'agent proactif, permissif, outillé et orienté action, active ce qui augmente sa puissance (agents, skills, rules, statusline, settings) sans me demander de micro-validations, adapte seulement ce qui dépend de ma machine, de mon stack et de mon style, protège mes secrets et fichiers privés existants, puis applique l'intégration la plus directe possible et résume ce que tu as changé.
```

## Prompt de mise à jour

Pour le mainteneur du repo: à chaque évolution de la config privée, collez ce prompt dans Claude Code pour resynchroniser le repo public.

```text
Mets à jour le repo public claude-config-public depuis ma config privée. Sources de vérité: ~/.claude pour settings.json, statusline.sh, rules/, agents/, CLAUDE.md, docs/, scripts/ et les skills propres au repo, et ~/.agents/skills pour les skills symlinkées. Vendorise les skills symlinkées en vrais fichiers, supprime du repo public les skills retirées de la config privée, et reporte les changements sous forme générique: aucune persona ni contexte privé, aucun nom, handle, email, entreprise ou projet personnel, aucun chemin utilisateur absolu, aucune commande propre à une distro, aucun pin de modèle lié à mon abonnement, et des placeholders pour les clés ou tokens d'exemple. Mets à jour les deux README et le .gitignore lorsque la structure change. Exécute les contrôles de guidance et de publication, corrige toute fuite, puis crée des commits atomiques en Conventional Commits et push.
```

## Checklist avant publication

Avant de rendre votre fork public:

```bash
./scripts/check-guidance.sh
git status --short
git ls-files
rg -n -i "token|secret|password|credential|api[_-]?key|private_key|BEGIN .* PRIVATE KEY|/home/|C:\\\\Users|\\.env"
rg -n -i "<your-name>|<your-handle>|<your-company>|<private-project>"
```

Supprimez les états locaux du suivi Git: `teams/`, caches de plugins, sessions, debug logs, shell snapshots, telemetry, file history, prompts, downloads, et tout répertoire généré par l'outil.

## Mise à jour

Gardez votre fork public générique. Mettez vos préférences vraiment personnelles dans une branche privée, un repo privé, ou `settings.local.json`. Le bon modèle: public pour la structure, privé pour l'identité.
