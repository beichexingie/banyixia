# 支付宝正式支付接入清单

## Supabase Edge Functions Secrets

正式环境至少需要配置以下变量：

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `ALIPAY_APP_ID`
- `ALIPAY_PRIVATE_KEY`
- `ALIPAY_PUBLIC_KEY`
- `ALIPAY_NOTIFY_URL`

说明：

- `ALIPAY_APP_ID`：支付宝开放平台正式应用的 `APPID`
- `ALIPAY_PRIVATE_KEY`：你自己的应用私钥，PKCS8 格式
- `ALIPAY_PUBLIC_KEY`：支付宝开放平台后台提供的“支付宝公钥”
- `ALIPAY_NOTIFY_URL`：正式异步通知地址，通常是 `https://<your-project>.supabase.co/functions/v1/alipay-notify`

## Flutter 正式环境

- 将 `ALIPAY_USE_SANDBOX` 设为 `false`
- 将 `pubspec.yaml` 中的 `alipay_payment.scheme` 改为 `alipay<正式APPID>`

## 数据库字段

执行 `supabase_payment_minimal.sql`，确保 `orders` 表至少包含：

- `payment_method`
- `payment_status`
- `payment_request_id`
- `merchant_order_no`
- `provider_trade_no`
- `paid_at`

## 正式支付闭环

当前项目的正式支付闭环如下：

1. App 调用 `alipay-create-order`
2. 后端生成 `order_string`
3. App 拉起支付宝客户端
4. 支付宝异步通知 `alipay-notify`
5. `alipay-notify` 验签、校验金额、更新订单状态
6. 后端将订单改为已支付，并补齐聊天房间与待结算资金

