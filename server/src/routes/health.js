import express from 'express';

import { config } from '../config.js';
import { pool } from '../db.js';
import { ok, fail } from '../utils/http.js';

export const healthRouter = express.Router();

healthRouter.get('/', async (_req, res) => {
  try {
    const nowResult = await pool.query('select now() as now');
    return ok(res, {
      message: 'server is healthy',
      node_env: config.nodeEnv,
      database_time: nowResult.rows[0]?.now ?? null,
    });
  } catch (error) {
    return fail(res, 500, `database check failed: ${error.message}`);
  }
});
