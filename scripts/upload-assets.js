#!/usr/bin/env node

/**
 * Upload assets to Cloudflare R2 bucket
 * Usage: node scripts/upload-assets.js
 * Environment variables:
 *   - CLOUDFLARE_ACCOUNT_ID
 *   - CLOUDFLARE_API_TOKEN
 *   - R2_BUCKET_NAME (default: neorgon-cdn-prod)
 */

const fs = require('fs');
const path = require('path');
require('dotenv').config();
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { Upload } = require('@aws-sdk/lib-storage');
const mime = require('mime-types');

const BASE_DIR = path.resolve(__dirname, '..');
const ASSETS_DIR = path.join(BASE_DIR, 'assets');

// Cache policy, stored on each R2 object and served as-is, because
// cdn.neorgon.org is an R2 custom domain (src/index.js is not in the path).
//
// Almost every asset keeps its bytes for the life of its versioned URL, so a
// year of immutable caching is right. header/season.css is the exception: it
// is the fleet's season switch, overwritten in place at the one URL every kit
// site links, and the header kit README promises that a season flips on the
// next page load. Under "immutable" a returning visitor would keep last
// season's file for up to a year, so it revalidates every five minutes.
const IMMUTABLE_CACHE = 'public, max-age=31536000, immutable';
const REVALIDATE_CACHE = 'public, max-age=300, must-revalidate';
const REVALIDATE_PATHS = new Set(['header/season.css']);

/**
 * Cache-Control for an asset, by its path relative to assets/
 */
function cacheControlFor(relativePath) {
  const normalized = relativePath.replace(/\\/g, '/');
  return REVALIDATE_PATHS.has(normalized) ? REVALIDATE_CACHE : IMMUTABLE_CACHE;
}

// Configuration
const ACCOUNT_ID = process.env.CLOUDFLARE_ACCOUNT_ID;
const ACCESS_KEY_ID = process.env.R2_ACCESS_KEY_ID;
const SECRET_ACCESS_KEY = process.env.R2_SECRET_ACCESS_KEY;
const BUCKET_NAME = process.env.R2_BUCKET_NAME || 'neorgon-cdn-prod';
const ENDPOINT = `https://${ACCOUNT_ID}.r2.cloudflarestorage.com`;

// Ensure required env vars
if (!ACCOUNT_ID || !ACCESS_KEY_ID || !SECRET_ACCESS_KEY) {
  console.error('❌ Missing environment variables:');
  console.error('   - CLOUDFLARE_ACCOUNT_ID');
  console.error('   - R2_ACCESS_KEY_ID');
  console.error('   - R2_SECRET_ACCESS_KEY');
  process.exit(1);
}

// S3 client for R2
const s3 = new S3Client({
  region: 'auto',
  endpoint: ENDPOINT,
  credentials: {
    accessKeyId: ACCESS_KEY_ID,
    secretAccessKey: SECRET_ACCESS_KEY,
  },
});

/**
 * Get all files in directory recursively
 */
function getAllFiles(dirPath, arrayOfFiles = []) {
  const files = fs.readdirSync(dirPath);

  files.forEach(file => {
    const fullPath = path.join(dirPath, file);
    if (fs.statSync(fullPath).isDirectory()) {
      arrayOfFiles = getAllFiles(fullPath, arrayOfFiles);
    } else {
      arrayOfFiles.push(fullPath);
    }
  });

  return arrayOfFiles;
}

/**
 * Upload a single file to R2
 */
async function uploadFile(filePath) {
  const relativePath = path.relative(ASSETS_DIR, filePath);
  const key = `v1.0.0/${relativePath}`.replace(/\\/g, '/'); // Use forward slashes

  const fileStream = fs.createReadStream(filePath);
  const contentType = mime.lookup(filePath) || 'application/octet-stream';
  const cacheControl = cacheControlFor(relativePath);

  console.log(`📤 Uploading: ${relativePath} (${contentType}; ${cacheControl})`);

  try {
    const upload = new Upload({
      client: s3,
      params: {
        Bucket: BUCKET_NAME,
        Key: key,
        Body: fileStream,
        ContentType: contentType,
        CacheControl: cacheControl,
      },
    });

    await upload.done();
    console.log(`   ✅ Uploaded: ${key}`);

    // Return metadata
    return {
      path: relativePath,
      key: key,
      size: fs.statSync(filePath).size,
      contentType: contentType,
    };
  } catch (error) {
    console.error(`   ❌ Failed: ${relativePath}`, error.message);
    throw error;
  }
}

/**
 * Main upload process
 */
async function main() {
  console.log('🚀 Starting asset upload to Cloudflare R2...\n');
  console.log(`📦 Bucket: ${BUCKET_NAME}`);
  console.log(`📁 Source: ${ASSETS_DIR}\n`);

  // Check if assets directory exists
  if (!fs.existsSync(ASSETS_DIR)) {
    console.error(`❌ Assets directory not found: ${ASSETS_DIR}`);
    process.exit(1);
  }

  // Get all files
  const files = getAllFiles(ASSETS_DIR);

  if (files.length === 0) {
    console.log('⚠️  No files found to upload.');
    process.exit(0);
  }

  console.log(`📊 Found ${files.length} files to upload\n`);

  // Upload files
  const results = [];
  let uploaded = 0;
  let failed = 0;

  for (const file of files) {
    try {
      const result = await uploadFile(file);
      results.push(result);
      uploaded++;
    } catch (error) {
      failed++;
    }
  }

  console.log('\n' + '═'.repeat(50));
  console.log('📈 Upload Complete!\n');
  console.log(`✅ Uploaded: ${uploaded} files`);
  console.log(`❌ Failed: ${failed} files\n`);

  // Calculate total size
  const totalSize = results.reduce((sum, r) => sum + r.size, 0);
  const totalSizeMB = (totalSize / 1024 / 1024).toFixed(2);
  console.log(`💾 Total size: ${totalSizeMB} MB`);

  // List uploaded files
  console.log('\n📋 Uploaded files:');
  results.forEach(r => {
    console.log(`   ${r.path}`);
  });

  // Generate summary
  const summaryPath = path.join(BASE_DIR, 'upload-summary.json');
  const summary = {
    timestamp: new Date().toISOString(),
    bucket: BUCKET_NAME,
    uploaded: uploaded,
    failed: failed,
    totalSize: totalSize,
    files: results.map(r => ({
      path: r.path,
      key: r.key,
      url: `https://cdn.neorgon.org/${r.key}`,
    })),
  };

  fs.writeFileSync(summaryPath, JSON.stringify(summary, null, 2));
  console.log(`\n💾 Summary saved: ${summaryPath}`);

  // Output URLs
  console.log('\n🔗 CDN URLs:');
  console.log(`   Logo: https://cdn.neorgon.org/v1.0.0/energon-classic-logo.png`);
  console.log(`   Favicon: https://cdn.neorgon.org/v1.0.0/favicon.ico`);

  process.exit(failed > 0 ? 1 : 0);
}

// Run main when invoked as a script (the workflow and `npm run upload-assets`
// both are); a require() gets the helpers without uploading anything.
if (require.main === module) {
  main().catch(error => {
    console.error('💥 Fatal error:', error);
    process.exit(1);
  });
}

module.exports = { cacheControlFor, uploadFile };
