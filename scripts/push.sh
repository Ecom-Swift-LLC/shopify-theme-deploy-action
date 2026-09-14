#!/usr/bin/env bash
# Deploys the theme at INPUT_PATH to a specific theme (INPUT_THEME) or, with
# INPUT_LIVE=true + INPUT_ALLOW_LIVE=true, to the store's live theme.
set -euo pipefail

if [ "${INPUT_LIVE:-false}" != "true" ] && [ -z "${INPUT_THEME:-}" ]; then
  echo "::error::mode 'push' needs either 'theme' (a theme ID or name) or 'live: true'." >&2
  exit 1
fi

if [ "${INPUT_LIVE:-false}" = "true" ] && [ "${INPUT_ALLOW_LIVE:-false}" != "true" ]; then
  echo "::error::pushing to the live theme needs 'allow-live: true' — this is Shopify CLI's own guard rail against overwriting a store's live theme by accident from CI." >&2
  exit 1
fi

args=(theme push --json --path "${INPUT_PATH:-.}")

if [ "${INPUT_LIVE:-false}" = "true" ]; then
  args+=(--live --allow-live)
else
  args+=(--theme "$INPUT_THEME")
fi

if [ "${INPUT_STRICT:-false}" = "true" ]; then
  args+=(--strict)
fi

while IFS= read -r pattern; do
  [ -n "$pattern" ] && args+=(--only "$pattern")
done <<< "${INPUT_ONLY:-}"

while IFS= read -r pattern; do
  [ -n "$pattern" ] && args+=(--ignore "$pattern")
done <<< "${INPUT_IGNORE:-}"

echo "Running: shopify ${args[*]}"
output="$(shopify "${args[@]}")"
echo "$output"

theme_id="$(echo "$output" | jq -r '.theme.id')"
preview_url="$(echo "$output" | jq -r '.theme.preview_url')"
editor_url="$(echo "$output" | jq -r '.theme.editor_url')"

if [ -z "$theme_id" ] || [ "$theme_id" = "null" ]; then
  echo "::error::couldn't find a theme ID in Shopify CLI's JSON output — see the raw output above." >&2
  exit 1
fi

{
  echo "theme-id=$theme_id"
  echo "preview-url=$preview_url"
  echo "editor-url=$editor_url"
} >> "$GITHUB_OUTPUT"
