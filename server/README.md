# yidianban server

这是地陪项目迁移到阿里云 `ECS + RDS PostgreSQL` 的第一版自建后端骨架。

## 当前已实现

- RDS PostgreSQL 连接
- 健康检查接口
- 支付宝 App 支付下单接口
- 支付宝异步通知接口
- 支付成功后：
  - 更新 `orders.payment_status`
  - 写入 `provider_trade_no`
  - 写入 `paid_at`
  - 增加地陪 `wallets.pending_balance`
  - 自动补 `chat_rooms`

## 目录

- `src/index.js`：服务入口
- `src/config.js`：环境变量配置
- `src/db.js`：PostgreSQL 连接池
- `src/routes/health.js`：健康检查
- `src/routes/payments.js`：支付相关路由
- `src/services/alipay.js`：支付宝签名与验签

## 本地启动

1. 复制环境变量模板：

```bash
cp .env.example .env
```

2. 修改 `.env`：

- `DATABASE_URL`
- `DATABASE_SSL`
- `ALIPAY_APP_ID`
- `ALIPAY_PRIVATE_KEY`
- `ALIPAY_PUBLIC_KEY`
- `ALIPAY_APP_CERT_SN`（商家转账/地陪提现必填）
- `ALIPAY_ROOT_CERT_SN`（商家转账/地陪提现必填）
- `ALIPAY_NOTIFY_URL`
- `CORS_ORIGINS`

3. 安装依赖：

```bash
npm install
```

4. 启动：

```bash
npm run dev
```

## ECS 部署最小步骤

1. 把项目拉到 ECS
2. 进入 `server/`
3. 执行：

```bash
npm install
cp .env.example .env
```

4. 填写 `.env`
5. 启动：

```bash
npm start
```

后续建议用 `pm2` 托管：

```bash
pm2 start src/index.js --name yidianban-server
pm2 save
```

## Flutter 客户端先改什么

先把后端地址切到 ECS：

```text
API_BASE_URL=https://api.your-domain.com/api
```

如果你只是先迁支付，也可以只配置：

```text
PAYMENT_BACKEND_BASE_URL=https://api.your-domain.com/api
```
