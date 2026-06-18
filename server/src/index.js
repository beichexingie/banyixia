import cors from 'cors';
import express from 'express';

import { config } from './config.js';
import { healthRouter } from './routes/health.js';
import { appRouter } from './routes/app.js';
import { paymentsRouter } from './routes/payments.js';

const app = express();

app.use(
  cors({
    origin: config.corsOrigins.length > 0 ? config.corsOrigins : true,
    credentials: true,
  }),
);
app.use(express.json({ limit: '2mb' }));
app.use((req, _res, next) => {
  const headerUserId = req.headers['x-user-id']?.toString().trim();
  const authHeader = req.headers.authorization?.toString().trim() ?? '';
  const bearerToken = authHeader.match(/^Bearer\s+(.+)$/i)?.[1]?.trim() ?? '';
  if (headerUserId) {
    req.sessionUserId = headerUserId;
  } else if (bearerToken) {
    req.authToken = bearerToken;
  }
  next();
});

app.get('/', (_req, res) => {
  res.json({
    success: true,
    message: 'yidianban server is running',
  });
});

app.use('/health', healthRouter);
app.use('/api/health', healthRouter);
app.use('/api', appRouter);
app.use('/api/payments', paymentsRouter);
app.use('/api', paymentsRouter);

app.listen(config.port, () => {
  console.log(`yidianban server listening on port ${config.port}`);
});
