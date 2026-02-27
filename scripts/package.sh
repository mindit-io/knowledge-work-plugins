#!/usr/bin/env bash
# Package individual plugins for upload as Organization skills in Cowork.
#
# Usage:
#   bash scripts/package.sh <plugin>        # package one plugin
#   bash scripts/package.sh all             # package every plugin
#
# Examples:
#   bash scripts/package.sh sales
#   bash scripts/package.sh partner-built/slack
#   bash scripts/package.sh all

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$REPO_ROOT/dist"
mkdir -p "$DIST_DIR"

package_plugin() {
  local plugin_dir="$1"          # e.g. sales  or  partner-built/slack
  local full_path="$REPO_ROOT/$plugin_dir"

  if [ ! -d "$full_path/.claude-plugin" ]; then
    echo "SKIP  $plugin_dir (no .claude-plugin/ directory)"
    return
  fi

  # Derive zip name: partner-built/slack -> partner-built-slack.zip
  local zip_name
  zip_name="$(echo "$plugin_dir" | tr '/' '-').zip"
  local out_file="$DIST_DIR/$zip_name"

  rm -f "$out_file"

  (cd "$full_path" && zip -r "$out_file" . \
    -x ".git/*" \
    -x "node_modules/*" \
    -x ".env" \
    -x "*.zip")

  local size
  size=$(du -k "$out_file" | cut -f1)
  echo "OK    $zip_name (${size} KB)"
}

# Discover all plugin directories (those containing .claude-plugin/)
discover_plugins() {
  local plugins=()
  for d in "$REPO_ROOT"/*/; do
    local name
    name="$(basename "$d")"
    [ "$name" = "scripts" ] && continue
    [ "$name" = "dist" ] && continue
    if [ -d "$d/.claude-plugin" ]; then
      plugins+=("$name")
    fi
    # Check one level deeper (partner-built/*)
    if [ "$name" = "partner-built" ]; then
      for sub in "$d"/*/; do
        local subname
        subname="$(basename "$sub")"
        if [ -d "$sub/.claude-plugin" ]; then
          plugins+=("partner-built/$subname")
        fi
      done
    fi
  done
  printf '%s\n' "${plugins[@]}"
}

if [ $# -eq 0 ]; then
  echo "Usage: bash scripts/package.sh <plugin|all>"
  echo ""
  echo "Available plugins:"
  discover_plugins | sed 's/^/  /'
  exit 1
fi

TARGET="$1"

if [ "$TARGET" = "all" ]; then
  echo "Packaging all plugins into dist/ ..."
  while IFS= read -r plugin; do
    package_plugin "$plugin"
  done < <(discover_plugins)
  echo ""
  echo "Done. Zips are in $DIST_DIR/"
else
  if [ ! -d "$REPO_ROOT/$TARGET" ]; then
    echo "Error: directory '$TARGET' not found"
    exit 1
  fi
  package_plugin "$TARGET"
fi
