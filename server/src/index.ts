import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { plansRouter } from './routes/plans.js';
import { meRouter } from './routes/me.js';
import { adminRouter } from './routes/admin.js';

const app = express();

const origins = (process.env.CORS_ORIGIN ?? 'http://localhost:5173')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

app.use(cors({ origin: origins, credentials: false }));
app.use(express.json({ limit: '1mb' }));

app.get('/health', (_req, res) => res.json({ ok: true }));

app.use('/api/plans', plansRouter);
app.use('/api/me', meRouter);
app.use('/api/admin', adminRouter);

// Fallback error handler so thrown/async errors return JSON, not HTML.
app.use((err: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('Unhandled error:', err);
  if (res.headersSent) return;
  res.status(500).json({ error: 'Internal server error.' });
});

const port = Number(process.env.PORT ?? 8787);
app.listen(port, () => {
  console.log(`API listening on http://localhost:${port} (CORS: ${origins.join(', ')})`);
});
