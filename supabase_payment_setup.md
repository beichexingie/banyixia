# 支付验证清单

你要完整模拟 `下单 -> 拉起支付宝 -> 回调 -> 入账`，还需要补这几项：

1. `SUPABASE_SERVICE_ROLE_KEY`
   - 用于 `alipay-notify` 写回订单、钱包、流水

2. `ALIPAY_APP_ID`
3. `ALIPAY_PRIVATE_KEY`
4. `ALIPAY_NOTIFY_URL`
   - 指向你的 Edge Function 回调地址

5. 先执行 `supabase_payment_minimal.sql`
6. 确认 `wallets` 和 `transactions` 表已存在

当前状态：
- App 可以请求支付宝订单串
- App 可以拉起支付宝客户端
- 订单表可以记录支付状态
- 但“回调验签 + 自动入账”还没做完
