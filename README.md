<div align="center">

# Neorgon CDN

Fast CDN for sharing assets across all Neorgon projects

[![Live][badge-site]][url-site]
[![Claude Code][badge-claude]][url-claude]
[![License][badge-license]](LICENSE)

[badge-site]:    https://img.shields.io/badge/live_site-0063e5?style=for-the-badge&logo=cloudflare&logoColor=white
[badge-claude]:  https://img.shields.io/badge/Claude_Code-CC785C?style=for-the-badge&logo=anthropic&logoColor=white
[badge-license]: https://img.shields.io/badge/license-MIT-404040?style=for-the-badge

[url-site]:   https://cdn.neorgon.com/
[url-claude]: https://claude.ai/code

</div>

---

## Overview

Cloudflare R2-powered CDN for delivering shared assets to all Neorgon sites. Stores logos, favicons, CSS variables, and JavaScript utilities in one place for faster loading and easier maintenance.

**Live:** cdn.neorgon.com

---

## Features

- **🚀 Global CDN** - Cloudflare edge caching
- **📦 Shared Assets** - Logo, favicon, CSS, JS utilities
- **💾 Version Control** - Assets versioned (v1.0.0/) for cache-busting
- **🔧 Auto-Upload** - Simple script to upload new assets
- **📊 Usage Dashboard** - See which assets are being served

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
| Logo | `https://cdn.neorgon.com/v1.0.0/energon-classic-logo.png` |
| Favicon | `https://cdn.neorgon.com/v1.0.0/favicon.ico` |
| CSS Base | `https://cdn.neorgon.com/v1.0.0/styles/base.css` |
| JS Utils | `https://cdn.neorgon.com/v1.0.0/utils/common.js` |

---

## Architecture

```
neorgon-cdn-site/
├── src/
│   └── index.js          # Cloudflare Worker for serving assets
├── scripts/
│   └── upload-assets.js  # Upload assets to R2 bucket
├── assets/
│   ├── energon-classic-logo.png
│   └── favicon.ico
├── wrangler.toml         # Cloudflare Worker config
├── package.json
├── index.html            # CDN info page
└── CNAME
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

---

## Features

- **[Feature name]** -- [what it does]
- **[Feature name]** -- [what it does]
- **[Feature name]** -- [what it does]

---

## Running locally

ES modules require an HTTP server (not `file://`):

```bash
make serve
```

Or manually:

```bash
python3 -m http.server 8000
```

---

## Architecture

```
[FOLDER_NAME]/
├── index.html          # HTML shell
├── css/
│   └── style.css       # All styles
├── js/
│   ├── app.js          # Entry point, imports and initializes
│   ├── state.js        # Shared state, localStorage
│   ├── render.js       # DOM rendering
│   ├── events.js       # Event handlers
│   └── utils.js        # Shared helpers
├── favicon.ico
├── energon-classic-logo.png
├── robots.txt
├── sitemap.xml
├── CNAME
├── Makefile
└── README.md
```

---

<div align="center">
<sub>Part of <a href="https://neorgon.com/">Neorgon</a></sub>
</div>
