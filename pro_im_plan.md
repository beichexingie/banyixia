# [NEW] IM 实时沟通系统实现计划 (Phase A)

我们将基于 Supabase Realtime 构建一套高性能、低延迟的即时通讯系统，连接用户与地陪。

## 1. 数据库架构 (Supabase)
### 1.1 `chat_rooms` (会话表)
- `id`: UUID (Primary Key)
- `participant_ids`: UUID[] (参与者列表，通常为两个：用户 + 地陪)
- `last_message`: TEXT (最后一条消息摘要)
- `last_message_time`: TIMESTAMP
- `order_id`: UUID (Optional, 关联的具体订单)

### 1.2 `messages` (消息表)
- `id`: UUID (Primary Key)
- `room_id`: UUID (Foreign Key -> chat_rooms)
- `sender_id`: UUID (Foreign Key -> users)
- `content`: TEXT
- `type`: TEXT (text, image, order_card)
- `is_read`: BOOLEAN
- `created_at`: TIMESTAMP

## 2. 核心逻辑 (Flutter)
### 2.1 `MessageProvider`
- 监听 Supabase Realtime 频道。
- 自动聚合未读消息数。
- 处理消息发送与本地即时预览（Optimistic Updates）。

### 2.2 流程闭环
- **地陪详情页** -> 点击“咨询” -> 创建/进入 `chat_room`。
- **消息列表页** -> 显示所有活跃会话。
- **聊天详情页** -> 实时收发、显示订单卡片引导转化。

## 3. 安全与风控
- **RLS 策略**：用户仅能查看/接收自己参与的 `chat_rooms` 和 `messages`。
- **图片安全**：发出的图片将触发内容安全扫描（通过 Supabase Edge Functions 或 RiskControlService 逻辑）。

---
**待办列表：**
- [ ] 编写并执行 `pro_im_init.sql`。
- [ ] 实现 `MessageProvider` 监听逻辑。
- [ ] 开发 `ChatRoomPage` (UI)。
- [ ] 开发 `ChatListPage` (UI)。
