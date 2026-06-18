# ECS 后端搭建说明

项目已经新增 `server/` 目录，作为第一版阿里云后端。

## 现在的工作方式

1. 本地改代码
2. 推送到 GitHub
3. ECS 执行 `git pull`
4. ECS 重启后端进程

不要把 ECS 当主开发环境。

## Flutter 侧先配的环境变量

优先设置：

```text
API_BASE_URL=https://api.your-domain.com/api
```

如果你暂时只想迁支付：

```text
PAYMENT_BACKEND_BASE_URL=https://api.your-domain.com/api
```

## 当前后端能力

- `GET /health`
- `GET /api/health`
- `POST /api/alipay-create-order`
- `POST /api/payments/alipay/notify`

为了兼容当前 Flutter 客户端，也保留了：

- `POST /api/alipay-create-order`

也就是客户端继续请求：

```text
{PAYMENT_BACKEND_BASE_URL}/alipay-create-order
```

时仍然能正常命中。

## ECS 初次部署

进入项目根目录后：

```bash
cd server
npm install
cp .env.example .env
```

填写 `.env`：

- `DATABASE_URL`
- `DATABASE_SSL`
- `ALIPAY_APP_ID`
- `ALIPAY_PRIVATE_KEY`
- `ALIPAY_PUBLIC_KEY`
- `ALIPAY_NOTIFY_URL`
- `CORS_ORIGINS`

启动：

```bash
npm start
```

## RDS 还需要补的 SQL

在阿里云 RDS 中执行：

- [rds_payment_runtime.sql](/D:/APP/flutter_application_1/server/sql/rds_payment_runtime.sql)

这份 SQL 负责补齐：

1. `orders` 支付字段
2. `wallets`
3. `transactions`
4. `chat_rooms` 最后消息字段与触发器

## 推荐生产托管

```bash
npm install -g pm2
pm2 start src/index.js --name yidianban-server
pm2 save
pm2 startup
```

## 下一步计划

第一批先迁：

1. 支付
2. 登录
3. 用户
4. 订单

第二批再迁：

1. 帖子
2. 需求
3. 上传
4. 聊天
