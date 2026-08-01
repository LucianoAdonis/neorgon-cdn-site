// Neorgon CDN Worker
// Serves assets from R2 bucket with proper CORS and caching

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const pathname = url.pathname;

    // Security: Only allow GET and HEAD requests
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return new Response('Method not allowed', { status: 405 });
    }

    // Remove leading slash
    const key = pathname.slice(1);

    // If no key provided, return index with asset listing
    if (!key || key === '') {
      return new Response('Neorgon CDN', {
        status: 200,
        headers: { 'Content-Type': 'text/plain' }
      });
    }

    try {
      // Get object from R2
      const object = await env.ASSETS_BUCKET.get(key);

      if (!object) {
        return new Response('Not found', { status: 404 });
      }

      // Determine content type
      const contentType = object.httpMetadata?.contentType || getContentType(key);

      // Set cache headers (1 year for immutable assets)
      const headers = new Headers();
      headers.set('Content-Type', contentType);
      headers.set('Cache-Control', 'public, max-age=31536000, immutable');
      headers.set('Access-Control-Allow-Origin', '*');
      headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
      headers.set('Access-Control-Max-Age', '86400');

      // Add CORS for preflight requests
      if (request.method === 'OPTIONS') {
        return new Response(null, { headers });
      }

      return new Response(object.body, { headers });

    } catch (error) {
      console.error('Error serving asset:', error);
      return new Response('Internal server error', { status: 500 });
    }
  }
};

// Helper function to determine content type from file extension
function getContentType(filename) {
  const ext = filename.split('.').pop().toLowerCase();
  const contentTypes = {
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'ico': 'image/x-icon',
    'svg': 'image/svg+xml',
    'css': 'text/css',
    'js': 'application/javascript',
    'json': 'application/json',
    'html': 'text/html',
    'txt': 'text/plain',
    'woff': 'font/woff',
    'woff2': 'font/woff2'
  };
  return contentTypes[ext] || 'application/octet-stream';
}
