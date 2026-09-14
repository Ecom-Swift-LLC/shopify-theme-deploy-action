# Shopify Theme Deploy — GitHub Action

A composite GitHub Action that pushes a Shopify theme with [Shopify CLI](https://shopify.dev/docs/api/shopify-cli) from CI: deploy to a fixed theme on merge, spin up a reusable preview theme per pull request, or clean one up when the PR closes.

**Free audit for your own store while you're here:** [full SEO + speed + CRO + AI-visibility check →](https://audit.ecomswiftllc.com/?utm_source=github&utm_medium=repo&utm_campaign=shopify-theme-deploy-action)

## Why this exists

`shopify theme push` is one command, but wiring it into CI is where people get stuck: which flag targets which theme, how do you avoid overwriting the live theme by accident from a bot, and how do you give every pull request its own throwaway preview without hand-managing theme IDs. This action answers those three questions with real Shopify CLI flags — no custom API wrapper, no reimplementation, just the CLI orchestrated safely and its actual JSON output surfaced as step outputs.

We build Shopify stores and themes day to day and kept hand-rolling this same workflow file per client, so we packaged it once.

## What it does

Three modes, one action:

| Mode | What it runs | Use it for |
| --- | --- | --- |
| `push` | `shopify theme push --theme <id>` (or `--live --allow-live`) | Deploying to a specific theme, e.g. on merge to `main` |
| `preview` | `shopify theme push --development --development-context <context>` | A reusable preview theme per PR — the same `context` (e.g. `pr-42`) updates the same theme on every new commit instead of creating a new one each time |
| `cleanup` | `shopify theme delete --theme <id> --force` | Deleting a PR's preview theme once the PR closes |

It installs Shopify CLI, runs the right command for the mode, and parses the `--json` output into three step outputs: `theme-id`, `preview-url`, `editor-url`.

## Example: a full PR-preview workflow

Three files, working together — the complete set is in [`examples/workflows/`](examples/workflows/):

**[`pr-preview.yml`](examples/workflows/pr-preview.yml)** — on every push to a PR, push a preview theme keyed by the PR number, then post (or update in place) a PR comment with the preview link and the editor link:

```yaml
- name: Push preview theme
  id: preview
  uses: Ecom-Swift-LLC/shopify-theme-deploy-action@v1
  with:
    mode: preview
    store: ${{ secrets.SHOPIFY_STORE }}
    theme-token: ${{ secrets.SHOPIFY_THEME_TOKEN }}
    context: pr-${{ github.event.pull_request.number }}
    path: theme
```

**[`pr-preview-cleanup.yml`](examples/workflows/pr-preview-cleanup.yml)** — on PR close, read the theme ID back out of that comment and delete the theme.

**[`deploy-on-push.yml`](examples/workflows/deploy-on-push.yml)** — on push to `main`, push straight to the production theme with `--strict` (Shopify CLI's own theme-check gate — the push fails if theme check finds errors).

Sample output posted to the PR:

> **Theme preview ready** for this PR:
> - [View storefront](https://your-shop.myshopify.com/?preview_theme_id=123456789)
> - [Open in theme editor](https://your-shop.myshopify.com/admin/themes/123456789/editor)

That preview link only tells you the theme deployed — it won't tell you if the store behind it is actually fast, indexable, or converting. If you want that too: [run the full audit](https://audit.ecomswiftllc.com/?utm_source=github&utm_medium=repo&utm_campaign=shopify-theme-deploy-action) against the preview URL before you merge.

## Inputs

| Input | Required | Default | Notes |
| --- | --- | --- | --- |
| `mode` | no | `push` | `push`, `preview`, or `cleanup` |
| `store` | yes | — | `your-shop.myshopify.com` or just `your-shop` |
| `theme-token` | yes | — | A [Theme Access](https://apps.shopify.com/theme-access) password, or an Admin API token with theme scopes. Store it as a secret. |
| `theme` | mode-dependent | — | Theme ID or name. Required for `push` (unless `live: true`) and for `cleanup` |
| `live` | no | `false` | `push` only — target the live theme instead of `theme` |
| `allow-live` | no | `false` | `push` only — required alongside `live: true`; this is Shopify CLI's own non-interactive safety check, not something this action invented |
| `context` | mode-dependent | — | `preview` only — stable ID for the reusable preview theme, e.g. `pr-${{ github.event.pull_request.number }}` |
| `path` | no | `.` | Path to the theme directory |
| `only` / `ignore` | no | — | Newline-separated glob patterns, forwarded to Shopify CLI's `--only` / `--ignore` (repeatable flags, one per line) |
| `strict` | no | `false` | Run theme check and require it to pass (warnings still allowed) before pushing |
| `cli-version` | no | `latest` | Shopify CLI version to install |

**Outputs:** `theme-id`, `preview-url`, `editor-url` (all empty in `cleanup` mode).

## Installation

Nothing to install into your theme repo — reference the action directly in a workflow:

```yaml
- uses: Ecom-Swift-LLC/shopify-theme-deploy-action@v1
```

Add two repository secrets first: `SHOPIFY_STORE` and `SHOPIFY_THEME_TOKEN` (create the token via the free [Theme Access app](https://apps.shopify.com/theme-access) — it needs no Partner account or custom app). For `deploy-on-push.yml`, also add `SHOPIFY_PROD_THEME_ID`.

## What it does **not** do

- **It is not a full CI pipeline.** It runs one `shopify theme` command per invocation — linting, testing, screenshot diffing, and Slack notifications are your workflow's job, not this action's.
- **It does not manage secrets rotation, scopes, or store permissions.** The Theme Access token you give it can do whatever that token is scoped for.
- **It does not diff Liquid changes or warn about breaking schema changes** — `--strict` runs theme check, which catches syntax and best-practice issues, not visual regressions.
- **It does not currently support Shopify's multi-environment `shopify.theme.toml` presets** beyond the `--listing` style Shopify CLI itself exposes — if you need per-environment theme settings files, layer that in your own workflow steps.
- **The `preview` mode's theme reuse depends entirely on `--development-context`**, a Shopify CLI feature, not something this action tracks itself — if Shopify CLI ever changes that flag's behavior, so does this action's guarantee of "same PR, same theme."

## FAQ

**Do I need a custom Shopify app to get a token?** No — the [Theme Access app](https://apps.shopify.com/theme-access) generates a password scoped to theme read/write with no Partner account required. An Admin API access token from a custom/private app also works if you already have one.

**Can I push to the live theme?** Yes, with `live: true` and `allow-live: true` set explicitly — that second flag exists because Shopify CLI itself refuses to touch the live theme from a non-interactive environment unless you say so twice. Treat it as a deliberate, reviewed step, not something you set once and forget.

**Why not just add a `run: shopify theme push ...` step myself?** You can — this action mainly saves you the CLI install step, the flag bookkeeping for the three real-world scenarios above, and the JSON parsing. If your case is simpler, a raw `run:` step is completely reasonable.

**Does this work with Shopify CLI's older `shopify theme push --theme=<n>` positional-style syntax?** The scripts use the current named-flag syntax (`--theme <value>`), verified against Shopify CLI 4.8.0's own `--help` output. Pin `cli-version` if you need to match an older CLI's flags exactly.

**One audit for the whole store — is that separate from this?** Yes. This action ships theme *code*; [our audit tool](https://audit.ecomswiftllc.com/?utm_source=github&utm_medium=repo&utm_campaign=shopify-theme-deploy-action) checks the *live storefront* for SEO, speed, CRO, and AI-visibility issues — useful right after a deploy to confirm nothing regressed.

## Related Shopify tools

From the same team:

- [shopify-store-audit-toolkit](https://github.com/EcomswiftLLC/shopify-store-audit-toolkit) — CLI that audits a live store's SEO, performance, and accessibility signals
- [shopify-theme-performance-auditor](https://github.com/Ecom-Swift-LLC/shopify-theme-performance-auditor) — checks a theme for large assets, render-blocking resources, and unused third-party scripts
- [shopify-accessible-components](https://github.com/Ecom-Swift-LLC/shopify-accessible-components) — WCAG-conscious drop-in Liquid components (modal, cart drawer, tabs, accordion, gallery)
- [shopify-store-optimization-checklist](https://github.com/Ecom-Swift-LLC/shopify-store-optimization-checklist) — the full merchant checklist: conversion, SEO, speed, AI visibility, analytics
- [shopify-seo-checklist](https://github.com/EcomswiftLLC/shopify-seo-checklist) — interactive technical + on-page SEO checklist

## Contributing

Issues and PRs welcome — bug reports, Shopify CLI compatibility reports (new CLI versions sometimes rename or add flags), and feature requests for additional modes.

## Roadmap

- [ ] Optional Slack/Discord notification step in the example workflows
- [ ] A `shopify theme check` step exposed as its own mode (currently folded into `strict`)
- [ ] Matrix example for deploying the same theme to multiple stores (markets/regions)

## License

MIT — see [LICENSE](LICENSE). © 2026 Ecom Swift LLC.

## Need help?

We're a Shopify Partner agency — this repo is one of the free tools we maintain alongside client work.

- 🔍 [Full store audit](https://audit.ecomswiftllc.com/?utm_source=github&utm_medium=repo&utm_campaign=shopify-theme-deploy-action) — SEO, speed, CRO, and AI-visibility in one report
- 🧰 [Free tools directory](https://www.ecomswiftllc.com/free-tools)
- 🤝 [Shopify Partner Directory profile](https://www.shopify.com/partners/directory/partner/waowy)
- 🌐 [ecomswiftllc.com](https://www.ecomswiftllc.com)

---

**Ecom Swift LLC** builds and maintains Shopify stores, themes, and the free tools in this GitHub org. [Get a free store audit](https://audit.ecomswiftllc.com/?utm_source=github&utm_medium=repo&utm_campaign=shopify-theme-deploy-action) · [Browse all free tools](https://www.ecomswiftllc.com/free-tools) · [www.ecomswiftllc.com](https://www.ecomswiftllc.com)
