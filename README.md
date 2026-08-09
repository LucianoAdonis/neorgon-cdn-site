<div align="center">

# Neorgon CDN

Fast CDN for sharing assets across all Neorgon projects

[![Live][badge-site]][url-site]
[![Claude Code][badge-claude]][url-claude]
[![License][badge-license]](LICENSE)

[badge-site]:    https://img.shields.io/badge/live_site-0063e5?style=for-the-badge&logo=cloudflare&logoColor=white
[badge-claude]:  https://img.shields.io/badge/Claude_Code-CC785C?style=for-the-badge&logo=anthropic&logoColor=white
[badge-license]: https://img.shields.io/badge/license-MIT-404040?style=for-the-badge

[url-site]:   https://cdn.neorgon.org/
[url-claude]: https://claude.ai/code

</div>

---

## Overview

Cloudflare R2-powered CDN for delivering shared assets to all Neorgon sites. Stores logos, favicons, CSS variables, and JavaScript utilities in one place for faster loading and easier maintenance.

**Live:** cdn.neorgon.org

> **What actually serves the assets.** `cdn.neorgon.org` is a custom domain bound **directly to
> the R2 bucket**, so the Worker in `src/index.js` is not currently in the request path: a live
> asset response carries no `Access-Control-Allow-Origin` (the Worker always sets one), `/`
> returns R2's own 404 page, and `/robots.txt` returns Cloudflare's managed file rather than the
> one in this repo. The Worker, `index.html`, `robots.txt` and `sitemap.xml` are therefore
> reference/fallback material, not what a browser reaches. `index.html` is `noindex` for that
> reason. Deploying assets means `npm run upload-assets`; there is no git deployment.

---

## Features

- **🚀 Global CDN** - Cloudflare edge caching
- **📦 Shared Assets** - Logo, favicon, CSS, JS utilities
- **💾 Version Control** - Assets versioned (`v1.0.0/`) and served `immutable`
- **🔧 Auto-Upload** - One script uploads `assets/` to R2 with the right content types

---

## Quick Start

### 1. Configure Cloudflare Credentials

```bash
cd neorgon-cdn-site
cp .env.example .env
# Edit .env with your Cloudflare credentials
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Deploy Worker

```bash
npm run deploy
```

### 4. Upload Assets

```bash
npm run upload-assets
```

---

## Asset URLs

| Asset | URL |
|-------|-----|
| Logo | `https://cdn.neorgon.org/v1.0.0/energon-classic-logo.png` |
| Favicon | `https://cdn.neorgon.org/v1.0.0/favicon.ico` |
| CSS Base | `https://cdn.neorgon.org/v1.0.0/styles/base.css` |
| JS Utils | `https://cdn.neorgon.org/v1.0.0/utils/common.js` |

---

## Architecture

```
neorgon-cdn-site/
├── src/
│   └── index.js          # Worker: serves R2 objects with CORS + immutable caching.
│                         #   Not in the live request path — see the note above.
├── scripts/
│   └── upload-assets.js  # Upload assets/ → R2 under v1.0.0/<relpath>. THE deploy path.
├── assets/               # Staged from packages/neorgon-ui/ in the monorepo
│   ├── energon-classic-logo.png
│   ├── favicon.ico
│   ├── header/           # header.css, header.js, themes.css, season.css
│   ├── footer/           # footer.css, footer.js
│   ├── styles/base.css   # canonical design tokens
│   └── utils/common.js
├── wrangler.toml         # Worker + R2 bucket bindings (prod / staging)
├── package.json
├── index.html            # Asset reference page, local-only (noindex)
├── robots.txt            # Not served; kept for the registry's asset flags
├── sitemap.xml           # Not served; kept for the registry's asset flags
└── CNAME                 # Inert here: a GitHub Pages mechanism, and Pages is off.
                          #   Cloudflare owns the cdn.neorgon.org record.
```

---

## Deploy

**Production:**
```bash
npm run deploy
```

**Staging:**
```bash
npm run deploy:staging
npm run upload-assets:staging
```

---

## Configuration

### Environment Variables

```bash
CLOUDFLARE_ACCOUNT_ID=your_account_id
CLOUDFLARE_API_TOKEN=your_api_token
R2_BUCKET_NAME=neorgon-cdn-prod
```

### Setup Cloudflare R2

1. Go to Cloudflare Dashboard → R2
2. Create bucket: `neorgon-cdn-prod`
3. Create API token with R2 permissions
4. Add credentials to `.env`

---

## Migrate Sites to CDN

See `/scripts/migrate-to-cdn.sh` in the main monorepo:

```bash
cd /path/to/Personal
./scripts/migrate-to-cdn.sh --dry-run    # Preview changes
./scripts/migrate-to-cdn.sh              # Migrate all projects
```

---

## Running locally

`make serve` (port 8845) renders `index.html` — the asset reference page. It is the only way to
see that page, since the live host serves R2 directly.

```bash
make serve
```

Worker development is separate, and needs Cloudflare credentials:

```bash
npm run dev      # wrangler dev
```

---

<div align="center">
<sub>Part of <a href="https://neorgon.com/">Neorgon</a></sub>
</div>
