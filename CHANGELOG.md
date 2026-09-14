# Changelog

## v1.0.0 — 2026-09-14

Initial release.

- `push` mode — deploy to a specific theme ID/name, or the live theme with explicit `live: true` + `allow-live: true`
- `preview` mode — reusable per-PR preview theme via Shopify CLI's `--development-context`
- `cleanup` mode — delete a theme by ID
- `theme-id`, `preview-url`, `editor-url` outputs parsed from Shopify CLI's `--json` output
- `only` / `ignore` glob filtering, `strict` theme-check gate, pinnable `cli-version`
- Example workflows: deploy-on-push, PR preview with auto-updating PR comment, PR preview cleanup
