# Neorgon CDN - Cloudflare R2 Setup Guide

Follow these steps to fully set up the CDN with Cloudflare R2.

## Prerequisites

- [ ] Cloudflare account (free tier works)
- [ ] Node.js and npm installed
- [ ] Wrangler CLI (`npm install -g wrangler`)
- [ ] Assets ready in `/neorgon-cdn-site/assets/`

---

## Step 1: Create R2 Bucket

**Via Cloudflare Dashboard:**
1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Navigate to **R2** → **Create bucket**
3. Name: `neorgon-cdn-prod`
4. Location: Choose nearest region
5. Click **Create**

**Via Wrangler CLI:**
```bash
cd neorgon-cdn-site
npx wrangler r2 bucket create neorgon-cdn-prod
```

---

## Step 2: Get API Credentials

1. Go to **R2** → **Manage R2 API Tokens**
2. Click **Create API token**
3. Name: `neorgon-cdn-prod`
4. Permissions: **Edit** (read + write)
5. Click **Create**
6. Copy the **Account ID**, the **Access Key ID** and the **Secret Access Key**

One R2 API token issues both the S3 key pair and a Cloudflare API token, so they share a
lifecycle and an IP filter — when uploads break, they break together.

---

## Step 3: Configure Environment

```bash
cd neorgon-cdn-site
cp .env.example .env
```

Edit `.env`:
```bash
CLOUDFLARE_ACCOUNT_ID=your_account_id_here
R2_ACCESS_KEY_ID=your_r2_access_key_id
R2_SECRET_ACCESS_KEY=your_r2_secret_access_key
R2_BUCKET_NAME=neorgon-cdn-prod

# Only wrangler (`npm run deploy`) uses this; the uploader ignores it.
CLOUDFLARE_API_TOKEN=your_api_token_here
```

`upload-assets.js` reaches R2 over the **S3-compatible API**, so the S3 key pair is what it
needs — an account id plus `CLOUDFLARE_API_TOKEN` alone will not upload anything. The secret is
exactly 64 hex characters; a `SignatureDoesNotMatch` usually means it was mis-pasted.

---

## Step 4: Upload Assets

```bash
# Make sure all assets are in /assets/
ls -la assets/

# Should show:
# assets/
# ├── favicon.ico
# ├── energon-classic-logo.png
# ├── styles/
# │   └── base.css
# └── utils/
#     └── common.js

# Install dependencies for upload script
npm install @aws-sdk/client-s3 @aws-sdk/lib-storage mime-types

# Upload to R2
npm run upload-assets
```

Expected output:
```
🚀 Starting asset upload to Cloudflare R2...

📦 Bucket: neorgon-cdn-prod
📁 Source: /path/to/neorgon-cdn-site/assets

📊 Found 4 files to upload

📤 Uploading: favicon.ico (image/x-icon)
   ✅ Uploaded: v1.0.0/favicon.ico
📤 Uploading: energon-classic-logo.png (image/png)
   ✅ Uploaded: v1.0.0/energon-classic-logo.png
📤 Uploading: styles/base.css (text/css)
   ✅ Uploaded: v1.0.0/styles/base.css
📤 Uploading: utils/common.js (application/javascript)
   ✅ Uploaded: v1.0.0/utils/common.js

📈 Upload Complete!

✅ Uploaded: 4 files
❌ Failed: 0 files

💾 Total size: 0.32 MB
```

---

## Step 5: Configure Custom Domain

> **Already done, and it is Option B.** `cdn.neorgon.org` is a custom domain connected
> **directly to the R2 bucket**. The Worker in `src/index.js` is therefore *not* in the request
> path — a live asset carries no `Access-Control-Allow-Origin` (the Worker always sets one), `/`
> returns R2's own 404, and `/robots.txt` returns Cloudflare's managed file. The steps below are
> the reference for rebuilding it, or for moving to Option C.

**Option A: Use R2.dev domain (Quick)**

Your bucket will be available at:
```
https://neorgon-cdn-prod.your-account.r2.dev
```

**Option B: Custom domain (Recommended)**

1. Go to **R2** → **Settings**
2. Under **Public Buckets**, click **Connect Domain**
3. Domain: `cdn.neorgon.org`
4. Follow DNS setup instructions:
   - Add CNAME record pointing to your R2 bucket
   - Enable proxy (orange cloud) for CDN benefits

**Option C: Cloudflare Worker (Full control)**

1. Deploy the Worker in `src/index.js`:
   ```bash
   npm install
   npm run deploy
   ```

2. Add custom domain to Worker:
   - Go to **Workers & Pages** → Your worker → **Settings**
   - Add custom domain: `cdn.neorgon.org`

3. Update DNS CNAME:
   ```
   cdn.neorgon.org → your-worker.your-account.workers.dev (proxied)
   ```

**Where this stands:** Option B is live. Option C is the upgrade worth making if the CDN ever
needs the Worker's behaviour — its own CORS headers, a real index at `/`, or this repo's
`robots.txt` — none of which reach a browser today.

---

## Step 6: Verify Upload

Check that assets are accessible in browser:

```
https://neorgon-cdn-prod.your-account.r2.dev/v1.0.0/favicon.ico
https://neorgon-cdn-prod.your-account.r2.dev/v1.0.0/energon-classic-logo.png
```

Or via curl:
```bash
curl -I https://cdn.neorgon.org/v1.0.0/favicon.ico
```

Should return:
```
HTTP/2 200
content-type: image/x-icon
content-length: 15406
cache-control: public, max-age=31536000, immutable
```

---

## Step 7: Test Migration Script

In the main monorepo:

```bash
cd /path/to/Personal

# Test on one project
./scripts/migrate-to-cdn.sh --project neorgon-site --dry-run

# If looks good, run for real
./scripts/migrate-to-cdn.sh --project neorgon-site

# Test the migrated site
./scripts/health-check.sh neorgon-site
```

---

## Step 8: Monitor Usage

**Via Cloudflare Dashboard:**
1. Go to **R2** → **neorgon-cdn-prod**
2. View **Metrics**: Requests, bandwidth, storage
3. Check **Access Logs** if needed

---

## Troubleshooting

### Upload fails with "Unauthorized"
- Check API token has **Edit** permissions
- Verify Account ID is correct (no dashes)
- Ensure `.env` file exists and is readable

### Assets return 404
- Verify asset was uploaded: check R2 bucket
- Check URL path: should be `/v1.0.0/asset-name.ext`

### Custom domain not working
- DNS propagation can take up to 24 hours
- Ensure CNAME is proxied (orange cloud)
- Check SSL/TLS mode is "Full (strict)"

---

## Quick Setup (One Command)

Run `./setup.sh` in the neorgon-cdn-site directory for a guided setup.

---

**Next Steps:** all three are done — the CDN is live on `cdn.neorgon.org`, the monorepo's
`scripts/migrate-to-cdn.sh` carries that host, and the fleet is migrated. The operational
runbook lives in the monorepo at `docs/operations/cdn.md`, with the design and the
credential-troubleshooting matrix in `docs/architecture/cdn.md`.
