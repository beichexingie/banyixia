import express from 'express';

import { config, hasAlipayConfig } from '../config.js';
import { pool, withTransaction } from '../db.js';
import {
  buildOrderString,
  queryAlipayTrade,
  verifyAlipaySignature,
} from '../services/alipay.js';
import {
  ensureChatRoom,
  findOrderById,
  findOrderByMerchantOrderNo,
  updateOrderPayment,
} from '../repositories/orders.js';
import {
  incrementPendingBalance,
  recordWalletTransaction,
} from '../repositories/wallets.js';
import { fail, ok } from '../utils/http.js';
import { notifyUser } from '../services/push_notifications.js';

export const paymentsRouter = express.Router();

function getRequestUserId(req) {
  return (
    req.headers['x-user-id']?.toString().trim() ||
    req.headers.authorization?.toString().replace(/^Bearer\s+/i, '').trim() ||
    ''
  );
}

async function settlePaidOrder(orderId, tradeNo) {
  let shouldNotify = false;
  const result = await withTransaction(async (client) => {
    const latestOrder = await findOrderById(client, orderId);
    if (!latestOrder) {
      throw new Error('订单不存在');
    }

    if (latestOrder.payment_status === 'paid') {
      return latestOrder;
    }
    shouldNotify = true;

    await updateOrderPayment(client, latestOrder.id, {
      payment_status: 'paid',
      status: 1,
      payment_request_id: latestOrder.payment_request_id ?? latestOrder.id,
      provider_trade_no: tradeNo,
      paid_at: new Date().toISOString(),
    });

    // Travel fees are paid by the customer but are not subject to the
    // platform commission. Use the server-calculated guide income here.
    const guideIncome = Number(latestOrder.guide_income ?? latestOrder.amount);

    await incrementPendingBalance(
      client,
      latestOrder.guide_id,
      guideIncome,
    );

    await recordWalletTransaction(client, {
      userId: latestOrder.guide_id,
      orderId: latestOrder.id,
      type: 'income_pending',
      amount: guideIncome,
      actualAmount: guideIncome,
      description: `订单收入托管到账：${latestOrder.service_name ?? '地陪服务订单'}`,
    });

    await ensureChatRoom(client, latestOrder.id, [
      latestOrder.user_id,
      latestOrder.guide_id,
    ]);

    return {
      ...latestOrder,
      payment_status: 'paid',
      provider_trade_no: tradeNo,
    };
  });
  if (shouldNotify) {
    await notifyUser(pool, result.user_id, {
      title: '支付成功',
      body: `${result.service_name || '订单'}已支付成功`,
      route: `/profile/orders/${result.id}`,
      type: 'payment_success',
      orderId: result.id,
    });
    await notifyUser(pool, result.guide_id, {
      title: '客户已付款',
      body: '订单已支付，可以查看服务安排',
      route: '/messages',
      type: 'payment_success',
      orderId: result.id,
    });
  }
  return result;
}

paymentsRouter.post('/alipay-create-order', async (req, res) => {
  const { order_id: orderId, merchant_order_no: merchantOrderNo, subject } =
      req.body ?? {};

  if (!orderId || !subject) {
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
    if (order.payment_status === 'paid') {
      return fail(res, 409, '订单已支付，请刷新订单状态');
    }

    const orderAmount = Number(order.amount);
    if (!Number.isFinite(orderAmount) || orderAmount <= 0) {
      return fail(res, 400, 'invalid order amount');
    }

    const built = buildOrderString({
      orderId: String(orderId),
      merchantOrderNo: merchantOrderNo?.toString() ?? order.merchant_order_no,
      amount: orderAmount,
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
        await settlePaidOrder(order.id, tradeNo);

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

paymentsRouter.get('/alipay-status/:id', async (req, res) => {
  const userId = getRequestUserId(req);
  if (!userId) return fail(res, 401, '请先登录');

  try {
    const order = await findOrderById(pool, req.params.id);
    if (!order) return fail(res, 404, '订单不存在');
    if (order.user_id !== userId && order.guide_id !== userId) {
      return fail(res, 403, '无权查看该订单');
    }

    if (order.payment_status !== 'paid' && order.merchant_order_no) {
      const alipay = await queryAlipayTrade({
        merchantOrderNo: order.merchant_order_no,
        tradeNo: order.provider_trade_no,
      });
      if (
        (alipay.tradeStatus === 'TRADE_SUCCESS' ||
          alipay.tradeStatus === 'TRADE_FINISHED') &&
        alipay.totalAmount.toFixed(2) === Number(order.amount).toFixed(2)
      ) {
        await settlePaidOrder(order.id, alipay.tradeNo);
      }
    }

    const latest = await findOrderById(pool, order.id);
    return ok(res, {
      data: {
        order_id: latest.id,
        payment_status: latest.payment_status,
        status: latest.status,
        payment_request_id: latest.payment_request_id,
        merchant_order_no: latest.merchant_order_no,
        provider_trade_no: latest.provider_trade_no,
      },
    });
  } catch (error) {
    return fail(res, 502, `查询支付宝支付状态失败：${error.message}`);
  }
});
