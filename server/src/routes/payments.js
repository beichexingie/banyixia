import express from 'express';

import { config, hasAlipayConfig } from '../config.js';
import { pool, withTransaction } from '../db.js';
import {
  buildOrderString,
  verifyAlipaySignature,
} from '../services/alipay.js';
import {
  ensureChatRoom,
  findOrderById,
  findOrderByMerchantOrderNo,
  updateOrderPayment,
} from '../repositories/orders.js';
import { incrementPendingBalance } from '../repositories/wallets.js';
import { fail, ok } from '../utils/http.js';

export const paymentsRouter = express.Router();

paymentsRouter.post('/alipay-create-order', async (req, res) => {
  const { order_id: orderId, merchant_order_no: merchantOrderNo, amount, subject } =
      req.body ?? {};

  if (!orderId || !amount || !subject) {
    return fail(res, 400, '缺少订单参数');
  }

  if (!hasAlipayConfig()) {
    return fail(res, 500, '支付宝环境变量未配置完整');
  }

  try {
    const order = await findOrderById(pool, String(orderId));
    if (!order) {
      return fail(res, 404, '订单不存在');
    }

    const built = buildOrderString({
      orderId: String(orderId),
      merchantOrderNo: merchantOrderNo?.toString() ?? order.merchant_order_no,
      amount: Number(amount),
      subject: String(subject),
    });

    await pool.query(
      `
        update public.orders
        set
          merchant_order_no = $2,
          payment_method = 'alipay',
          payment_status = coalesce(payment_status, 'pending')
        where id = $1
      `,
      [String(orderId), built.merchantOrderNo],
    );

    return ok(res, {
      message: '支付宝订单参数已生成',
      payment_request_id: String(orderId),
      order_string: built.orderString,
      debug_meta: built.debugMeta,
    });
  } catch (error) {
    return fail(res, 500, `生成支付宝订单失败: ${error.message}`);
  }
});

paymentsRouter.post(
  '/alipay/notify',
  express.urlencoded({ extended: false }),
  async (req, res) => {
    if (!hasAlipayConfig()) {
      return res.status(500).type('text/plain').send('fail');
    }

    const params = Object.fromEntries(
      Object.entries(req.body ?? {}).map(([key, value]) => [key, String(value)]),
    );

    try {
      const verified = verifyAlipaySignature(params);
      if (!verified) {
        return res.status(400).type('text/plain').send('fail');
      }

      const appId = params.app_id?.trim();
      if (appId !== config.alipayAppId) {
        return res.status(400).type('text/plain').send('fail');
      }

      const merchantOrderNo = params.out_trade_no?.trim() ?? '';
      const tradeNo = params.trade_no?.trim() ?? '';
      const tradeStatus = params.trade_status?.trim() ?? '';
      const totalAmount = Number(params.total_amount ?? '0');

      if (!merchantOrderNo || !tradeNo || !tradeStatus || !(totalAmount > 0)) {
        return res.status(400).type('text/plain').send('fail');
      }

      const order = await findOrderByMerchantOrderNo(pool, merchantOrderNo);
      if (!order) {
        return res.status(404).type('text/plain').send('fail');
      }

      if (Number(order.amount).toFixed(2) !== totalAmount.toFixed(2)) {
        return res.status(400).type('text/plain').send('fail');
      }

      if (tradeStatus === 'TRADE_SUCCESS' || tradeStatus === 'TRADE_FINISHED') {
        await withTransaction(async (client) => {
          const latestOrder = await findOrderByMerchantOrderNo(client, merchantOrderNo);
          if (!latestOrder) {
            throw new Error('订单不存在');
          }

          const alreadyPaid =
              latestOrder.payment_status === 'paid' &&
              latestOrder.provider_trade_no === tradeNo;

          if (alreadyPaid) {
            return;
          }

          await updateOrderPayment(client, latestOrder.id, {
            payment_status: 'paid',
            status: 1,
            payment_request_id:
                latestOrder.payment_request_id ?? latestOrder.id,
            provider_trade_no: tradeNo,
            paid_at: new Date().toISOString(),
          });

          await incrementPendingBalance(
            client,
            latestOrder.guide_id,
            Number(latestOrder.amount),
          );

          await ensureChatRoom(client, latestOrder.id, [
            latestOrder.user_id,
            latestOrder.guide_id,
          ]);
        });

        return res.type('text/plain').send('success');
      }

      if (tradeStatus === 'TRADE_CLOSED') {
        await pool.query(
          `
            update public.orders
            set
              payment_status = 'closed',
              provider_trade_no = coalesce($2, provider_trade_no)
            where merchant_order_no = $1
          `,
          [merchantOrderNo, tradeNo],
        );

        return res.type('text/plain').send('success');
      }

      return res.type('text/plain').send('success');
    } catch (error) {
      return res.status(500).type('text/plain').send('fail');
    }
  },
);
