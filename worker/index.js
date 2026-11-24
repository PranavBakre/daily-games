// Serves the static PWA from /games/ and keeps the apex pointing at it. Asset
// lookups are path-relative, so dist/web/games/* answers /games/* directly.

const SLUG = '/games';

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === '/' || url.pathname === SLUG) {
      return Response.redirect(`${url.origin}${SLUG}/`, 302);
    }

    if (!url.pathname.startsWith(`${SLUG}/`)) {
      return new Response('Not found', { status: 404 });
    }

    const response = await env.ASSETS.fetch(request);
    if (url.pathname === `${SLUG}/sw.js` || url.pathname === `${SLUG}/index.html`) {
      const headers = new Headers(response.headers);
      headers.set('Cache-Control', 'no-cache');
      return new Response(response.body, { status: response.status, headers });
    }

    return response;
  },
};
