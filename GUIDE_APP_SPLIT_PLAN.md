# 地陪端独立目录说明

## 现在的目录

客户端继续放在仓库根目录，地陪端单独放到新的 `guide_app/` 目录里：

```text
flutter_application_1/
├─ lib/                         # 客户端
├─ server/                      # 后端
├─ guide_app/                   # 地陪端独立工程
│  ├─ pubspec.yaml
│  └─ lib/
│     ├─ main.dart
│     ├─ guide_app/
│     │  ├─ guide_app.dart
│     │  ├─ pages/
│     │  ├─ providers/
│     │  ├─ widgets/
│     │  └─ models/
│     ├─ bootstrap/             # 共享层桥接
│     ├─ config/                # 共享层桥接
│     ├─ models/                # 共享层桥接
│     ├─ pages/                 # 共享层桥接
│     └─ providers/             # 共享层桥接
└─ ...
```

这次不再是 `lib/main_guide.dart` 和 `lib/guide_app/` 那种“还混在客户端工程里”的结构。

## 当前已经落好的内容

`guide_app/lib/guide_app/` 里已经放好了参考 `地陪.pdf` 第 9-20 页做出的地陪端 UI 骨架和初步逻辑：

- 订单中心
- 工作台
- 路线页
- 接单设置
- 接单模式
- 服务类型
- 城市选择
- 服务地点
- 服务项目选择
- 消息页
- 我的页

目前这部分属于“前端骨架 + 本地状态 + 复用现有接口”的第一版，后续再逐步替换为专用后端接口。

## 两端之间怎么处理

### 1. 数据库

数据库继续共用，不拆库。

核心表继续共用：

- `users`
- `orders`
- `posts`
- `chat_rooms`
- `messages`
- `guide_applications`

也就是说：客户端和地陪端是两套前端视角，不是两套业务数据。

### 2. 账号体系

建议继续共用一套账号，不要再拆第二套登录体系。

判断方式保持现在这套：

- 普通用户：客户端使用
- 已认证地陪：客户端 + 地陪端都能使用

实际判断字段继续走：

- `users.is_guide`
- `guide_application_status`

### 3. 后端接口

短期先共用你现在的 `/api`。

已经可以直接复用的：

- `/api/auth/send-code`
- `/api/auth/verify-code`
- `/api/users/me`
- `/api/orders`
- `/api/posts`
- `/api/chat/rooms`

建议后面新增地陪端专用接口命名空间，例如：

- `GET /api/guide-console/summary`
- `GET /api/guide-console/orders`
- `POST /api/guide-console/orders/:id/arrived`
- `GET /api/guide-console/settings`
- `PUT /api/guide-console/settings`
- `GET /api/guide-console/addresses`
- `POST /api/guide-console/addresses`

这样后面客户端和地陪端不会互相污染接口语义。

### 4. 代码复用方式

这次我没有把公共代码复制两份，而是让 `guide_app/` 通过 `path` 依赖复用主工程的共享层：

```yaml
flutter_application_1:
  path: ..
```

地陪端现在复用这些公共能力：

- `bootstrap/app_bootstrap.dart`
- `config/app_theme.dart`
- `providers/user_provider.dart`
- `providers/order_provider.dart`
- `providers/post_provider.dart`
- `providers/message_provider.dart`
- `pages/auth/login_page.dart`
- `pages/home/post_create_page.dart`
- `pages/messages/chat_room_page.dart`
- `models/order.dart`
- `models/user.dart`

这样现在先跑得快，后面如果共享代码越来越多，再把这部分抽成真正的 `shared_core` package。

## 你后面怎么跑

### 跑客户端

在仓库根目录：

```bash
flutter pub get
flutter run -t lib/main.dart --dart-define=API_BASE_URL=https://api.your-domain.com/api --dart-define=PAYMENT_BACKEND_BASE_URL=https://api.your-domain.com/api
```

### 跑地陪端

先进入独立目录：

```bash
cd guide_app
```

然后：

```bash
flutter pub get
flutter run -t lib/main.dart --dart-define=API_BASE_URL=https://api.your-domain.com/api --dart-define=PAYMENT_BACKEND_BASE_URL=https://api.your-domain.com/api
```

如果你后面要补安卓、iOS、Web 的平台壳子，就在 `guide_app/` 目录里执行：

```bash
flutter create . --project-name yidianban_guide_app --platforms=android,ios,web --no-pub
```

## 下一步最合理的顺序

1. 先把地陪端当成独立工程继续做 UI 和流程。
2. 让地陪认证账号可以正常登录 `guide_app`。
3. 后端补 `guide-console` 相关接口。
4. 再把工作台和订单中心里的占位数据换成真实接口。
5. 最后再单独处理地陪端包名、图标、启动页和上架材料。
