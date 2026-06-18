# yidianban

地陪系统 Flutter 客户端项目，当前已补充第一版阿里云自建后端骨架。

## 当前结构

- `lib/`：Flutter 客户端
- `supabase/functions/`：原有 Supabase Edge Function
- `server/`：第一版 `ECS + RDS` 自建后端

## 当前迁移状态

已完成：

- Supabase 业务数据迁移到阿里云 RDS PostgreSQL
- 第一版 Node.js 后端骨架
- 支付宝下单/回调后端迁移骨架

待完成：

- 登录迁移
- 用户/订单/帖子/需求接口迁移
- 上传迁移
- 聊天迁移

## Flutter 支付后端地址

当前 Flutter 通过 `PAYMENT_BACKEND_BASE_URL` 控制支付后端地址。

如果仍走 Supabase：

```bash
--dart-define=PAYMENT_BACKEND_BASE_URL=https://your-project.supabase.co/functions/v1
```

如果切到 ECS：

```bash
--dart-define=PAYMENT_BACKEND_BASE_URL=http://你的ECS公网IP:3000/api
```

## 后端说明

详见：

- [ECS_BACKEND_SETUP.md](/D:/APP/flutter_application_1/ECS_BACKEND_SETUP.md)
- [server/README.md](/D:/APP/flutter_application_1/server/README.md)
