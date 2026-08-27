import cors from 'cors';
import express from 'express';
import multer from 'multer';
import path from 'path';
import { fileURLToPath } from 'url';

import { config } from './config.js';
import { healthRouter } from './routes/health.js';
import { appRouter } from './routes/app.js';
import { paymentsRouter } from './routes/payments.js';
import { adminRouter } from './routes/admin.js';
import { guideRouter } from './routes/guide.js';

const app = express();
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const uploadsDir = path.resolve(__dirname, '../uploads');
const adminDir = path.resolve(__dirname, '../public/admin');

app.use(
  cors({
    origin: config.corsOrigins.length > 0 ? config.corsOrigins : true,
    credentials: true,
  }),
);
app.use(
  express.json({
    limit: '12mb',
    verify: (req, _res, buffer) => {
      if (req.originalUrl.includes('/wechat/notify')) {
        req.rawBody = Buffer.from(buffer);
      }
    },
  }),
);
app.use('/uploads', express.static(uploadsDir));
app.use('/admin', express.static(adminDir));
app.get('/admin', (_req, res) => {
  res.sendFile(path.join(adminDir, 'index.html'));
});
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
app.use('/api/admin', adminRouter);
app.use('/api/guide', guideRouter);
app.use('/api', appRouter);
app.use('/api/payments', paymentsRouter);
app.use('/api', paymentsRouter);

app.use((error, _req, res, next) => {
  if (error instanceof multer.MulterError && error.code === 'LIMIT_FILE_SIZE') {
    return res.status(413).json({
      success: false,
      message: '图片不能超过10MB，请压缩后重试',
    });
  }
  return next(error);
});

app.listen(config.port, () => {
  console.log(`yidianban server listening on port ${config.port}`);
});
