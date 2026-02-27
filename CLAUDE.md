# Knowledge Work Plugins — Developer Guide

Plugins that turn Claude into a specialist for a given role. Built for Cowork, also compatible with Claude Code.

## Repository Structure

```
plugin-name/                      <- one directory per plugin
  .claude-plugin/plugin.json      <- manifest (name, version, description)
  .mcp.json                       <- MCP server / connector config
  README.md                       <- plugin documentation
  CONNECTORS.md                   <- tool-category mapping (~~CRM, ~~calendar, …)
  commands/*.md                   <- slash commands (explicit workflows)
  skills/*/SKILL.md               <- auto-triggered domain knowledge
partner-built/                    <- third-party plugins (same structure inside)
.claude-plugin/marketplace.json   <- global marketplace registry
scripts/                          <- packaging scripts (not included in zips)
dist/                             <- generated zips (gitignored)
```

Everything is file-based — markdown and JSON, no code, no build steps.

## Packaging for Org Upload (Cowork)

To upload a plugin as an Organization skill in Cowork, package it as a zip:

```bash
# Unix / Git Bash
bash scripts/package.sh sales                   # one plugin
bash scripts/package.sh partner-built/slack      # partner plugin
bash scripts/package.sh all                      # all plugins

# Windows PowerShell
powershell -ExecutionPolicy Bypass -File scripts/package.ps1 sales
powershell -ExecutionPolicy Bypass -File scripts/package.ps1 all
```

Output lands in `dist/` (e.g. `dist/sales.zip`, `dist/partner-built-slack.zip`).
Each zip excludes `.git/`, `node_modules/`, `.env`, and other zips.

## Adding / Editing Plugins

1. Create or edit files under `plugin-name/` following the structure above.
2. Bump the version in `.claude-plugin/plugin.json`.
3. Update `README.md` inside the plugin if commands or skills changed.
4. Run the package script and upload the zip to Cowork org settings.
