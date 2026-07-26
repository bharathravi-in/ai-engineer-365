import 'dotenv/config';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import { meRouter } from './routes/me.js';
import { tracksRouter } from './routes/tracks.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const isProd = process.env.NODE_ENV === 'production';

const app = express();

// Correct client IPs (rate limiting, logs) when behind a reverse proxy / LB.
app.set('trust proxy', Number(process.env.TRUST_PROXY ?? 1));

const origins = (process.env.CORS_ORIGIN ?? 'http://localhost:5173')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

// Security headers. CSP is left to the edge/CDN (the SPA loads Google Fonts and
// talks to Supabase); disabling it here avoids breaking those cross-origin loads.
app.use(helmet({ contentSecurityPolicy: false, crossOriginEmbedderPolicy: false }));
app.use(compression());
app.use(cors({ origin: origins, credentials: false }));
app.use(express.json({ limit: '1mb' }));
app.use(
  morgan(isProd ? 'combined' : 'dev', {
    skip: (req) => req.url === '/health',
  }),
);

// Liveness/readiness probe (no rate limit).
app.get('/health', (_req, res) => res.json({ ok: true, uptime: process.uptime() }));

// Rate limit the API. Tune with RATE_LIMIT_MAX / RATE_LIMIT_WINDOW_MS.
const apiLimiter = rateLimit({
  windowMs: Number(process.env.RATE_LIMIT_WINDOW_MS ?? 15 * 60 * 1000),
  max: Number(process.env.RATE_LIMIT_MAX ?? 600),
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests — please slow down.' },
});
// Stricter cap for state-changing admin/enrollment writes.
const writeLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: Number(process.env.WRITE_RATE_LIMIT_MAX ?? 120),
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many writes — please slow down.' },
});

app.use('/api', apiLimiter);
app.use('/api/tracks/admin', writeLimiter);

app.use('/api/tracks', tracksRouter);
app.use('/api/me', meRouter);

// Unknown API routes → JSON 404 (not the SPA fallback below).
app.use('/api', (_req, res) => res.status(404).json({ error: 'Not found.' }));

// -------------------------------------------------------------------------
// Serve the built frontend (single-service deploy). Enabled in production or
// whenever a built app/dist exists. Override the location with STATIC_DIR.
// -------------------------------------------------------------------------
const staticDir = resolve(process.env.STATIC_DIR ?? join(__dirname, '../../app/dist'));
const serveStatic = process.env.SERVE_STATIC !== 'false' && existsSync(join(staticDir, 'index.html'));
if (serveStatic) {
  app.use(express.static(staticDir, { maxAge: '1h', index: false }));
  // SPA fallback: any non-API GET returns index.html.
  app.get(/^\/(?!api\/|health).*/, (_req, res) => res.sendFile(join(staticDir, 'index.html')));
  console.log(`Serving frontend from ${staticDir}`);
}

// Fallback error handler so thrown/async errors return JSON, not HTML.
app.use((err: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('Unhandled error:', err);
  if (res.headersSent) return;
  res.status(500).json({ error: 'Internal server error.' });
});

const port = Number(process.env.PORT ?? 8787);
const server = app.listen(port, () => {
  console.log(`API listening on :${port} (env: ${isProd ? 'production' : 'development'}, CORS: ${origins.join(', ')})`);
});

// Graceful shutdown.
for (const sig of ['SIGTERM', 'SIGINT'] as const) {
  process.on(sig, () => {
    console.log(`${sig} received — shutting down.`);
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 10_000).unref();
  });
}
