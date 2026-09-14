#!/usr/bin/env bash
# Deletes a theme by ID — used to remove a PR's preview theme once the PR
# closes. --force skips the interactive confirmation Shopify CLI would
# otherwise prompt for.
set -euo pipefail

if [ -z "${INPUT_THEME:-}" ]; then
  echo "::error::mode 'cleanup' needs 'theme' — the theme ID to delete." >&2
  exit 1
fi

echo "Running: shopify theme delete --theme $INPUT_THEME --force"
shopify theme delete --theme "$INPUT_THEME" --force
