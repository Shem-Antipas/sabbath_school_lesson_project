import { Hono } from 'hono'
import { cors } from 'hono/cors'

const app = new Hono()
const UPSTREAM = 'https://sabbath-school.adventech.io/api/v1'

// 1. GLOBAL CORS
app.use('/*', cors({
  origin: '*', 
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
}))

// ---------------------------------------------------------
// 2. SPECIFIC DAY CONTENT (Reader Screen)
// Matches: /quarterly/en/2026-01/01/01
// ---------------------------------------------------------
app.get('/quarterly/:lang/:quarterly/:lesson/:day', async (c) => {
  const { lang, quarterly, lesson, day } = c.req.param();
  const url = `${UPSTREAM}/${lang}/quarterlies/${quarterly}/lessons/${lesson}/days/${day}/read/index.json`;
  
  console.log(`📖 Fetching Day Read: ${url}`);

  try {
    const response = await fetch(url);
    if (!response.ok) {
      return c.json({ error: "Day content not found", status: response.status }, 404);
    }
    const data = await response.json();
    return c.json(data);
  } catch (e) {
    return c.json({ error: "Proxy failed", details: e.message }, 500);
  }
});

// ---------------------------------------------------------
// 3. LESSON INDEX (List of Days for a week)
// Matches: /quarterly/en/2026-01/01
// ---------------------------------------------------------
app.get('/quarterly/:lang/:quarterly/:lesson', async (c) => {
  const { lang, quarterly, lesson } = c.req.param();
  const url = `${UPSTREAM}/${lang}/quarterlies/${quarterly}/lessons/${lesson}/index.json`;
  
  console.log(`📑 Fetching Lesson Index: ${url}`);

  try {
    const response = await fetch(url);
    if (!response.ok) {
      return c.json({ error: "Lesson index not found", status: response.status }, 404);
    }
    const data = await response.json();
    return c.json(data);
  } catch (e) {
    return c.json({ error: "Proxy failed", details: e.message }, 500);
  }
});

// ---------------------------------------------------------
// 4. QUARTERLY INDEX (List of 13 Lessons)
// Matches: /quarterly/en/2026-01
// ---------------------------------------------------------
app.get('/quarterly/:lang/:quarterlyId', async (c) => {
  const { lang, quarterlyId } = c.req.param();
  const url = `${UPSTREAM}/${lang}/quarterlies/${quarterlyId}/index.json`;
  
  console.log(`📚 Fetching Quarterly List: ${url}`);

  try {
    const response = await fetch(url);
    if (!response.ok) return c.json({ error: 'Quarterly not found' }, 404);
    const data = await response.json();
    return c.json(data);
  } catch (err) {
    return c.json({ error: 'Proxy Error', details: err.message }, 500);
  }
});

// ---------------------------------------------------------
// 5. MAIN QUARTERLY LIST (Home Screen)
// Matches: /quarterlies/en
// ---------------------------------------------------------
app.get('/quarterlies/:lang', async (c) => {
  const lang = c.req.param('lang');
  const url = `${UPSTREAM}/${lang}/quarterlies/index.json`;
  
  try {
    const response = await fetch(url);
    const data = await response.json();
    return c.json(data);
  } catch (err) {
    return c.json({ error: 'Failed to load home screen', details: err.message }, 500);
  }
});

// ---------------------------------------------------------
// 6. IMAGE PROXY
// ---------------------------------------------------------
app.get('/proxy-image', async (c) => {
  const imageUrl = c.req.query('url');
  if (!imageUrl) return c.text('Missing URL', 400);

  try {
    const response = await fetch(imageUrl);
    const blob = await response.blob();
    return new Response(blob, {
      headers: {
        'Content-Type': response.headers.get('Content-Type') || 'image/png',
        'Access-Control-Allow-Origin': '*',
      },
    });
  } catch (e) {
    return c.text('Image fetch failed', 500);
  }
});

export default app