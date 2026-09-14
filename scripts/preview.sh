#!/usr/bin/env bash
# Pushes to a development theme keyed by INPUT_CONTEXT (Shopify CLI's
# --development-context): the same context reuses the same theme, so pushing
# again on new commits to a PR updates the existing preview instead of
# creating a new theme each time.
set -euo pipefail

context="${INPUT_CONTEXT:-}"
if [ -z "$context" ]; then
  echo "::error::mode 'preview' needs 'context' — a stable ID for the preview theme, e.g. pr-\${{ github.event.pull_request.number }}." >&2
  exit 1
fi

args=(theme push --json --development --development-context "$context" --path "${INPUT_PATH:-.}")

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
