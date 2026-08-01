#!/bin/bash
# Quick setup script for Neorgon CDN

set -e

echo "🚀 Neorgon CDN Setup"
echo "===================="
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v node &> /dev/null; then
  echo "❌ Node.js not found. Please install Node.js."
  exit 1
fi

echo "✅ Node.js found"

if ! command -v wrangler &> /dev/null; then
  echo "⚠️  Wrangler not found. Installing..."
  npm install -g wrangler
fi

echo "✅ Wrangler found"
echo ""

# Check if in correct directory
if [ ! -f "wrangler.toml" ]; then
  echo "❌ Not in neorgon-cdn-site directory"
  exit 1
fi

echo "📍 In correct directory"
echo ""

# Instructions
echo ""
echo "✨ Next steps:"
echo ""
echo "1️⃣  Create R2 bucket:"
echo "   wrangler r2 bucket create neorgon-cdn-prod"
echo ""
echo "2️⃣  Get API token:"
echo "   - Go to https://dash.cloudflare.com/"
echo "   - R2 → Manage R2 API Tokens"
echo "   - Create with Edit permissions"
echo ""
echo "3️⃣  Configure .env file:"
echo "   cp .env.example .env"
echo "   # Edit .env with your credentials"
echo ""
echo "4️⃣  Install dependencies:"
echo "   npm install"
echo ""
echo "5️⃣  Deploy Worker:"
echo "   npm run deploy"
echo ""
echo "6️⃣  Upload assets:"
echo "   npm run upload-assets"
echo ""
echo "7️⃣  Configure custom domain (cdn.neorgon.com)"
echo ""
echo "For detailed instructions, see SETUP.md"
echo ""
