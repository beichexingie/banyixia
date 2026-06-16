# 伴一下项目阿里云部署配置单

更新时间：2026-05-28

适用前提：
- 当前 Flutter 客户端继续保留。
- 后端准备逐步从 Supabase 迁移到阿里云。
- 目标是“测试可持续推进 + 后续能平滑上线”，不是只买一台最低配机器临时试验。

---

## 1. 最终推荐架构

本项目按下面这套架构采购和部署：

- 1 台阿里云 ECS 作为应用服务器
- 1 台阿里云 RDS PostgreSQL 作为主数据库
- 1 个阿里云 OSS Bucket 作为图片/附件存储
- 1 个阿里云域名
- 1 套中国内地备案能力
- 1 个阿里云短信服务
- 地图、支付继续接第三方 API

当前阶段不购买：

- 不购买 ALB
- 不购买 Redis
- 不购买 K8s
- 不做双机热备

原因：
- 你当前项目体量不需要一上来就做多机负载均衡
- 现在最重要的是把后端 API、数据库、短信、支付、地图、备案整条链打通
- 先用“1 台 ECS + 1 台 RDS + 1 个 OSS”最稳、最省事、最容易维护

---

## 2. 推荐采购配置

### 2.1 阿里云账号要求

必须使用：

- 企业实名认证阿里云账号

原因：

- 后续短信签名、支付、备案、正式运营，企业资质最省事
- 个人实名认证虽然能买服务器，但在短信、支付、备案、长期运营方面限制更大

官方说明：
- 阿里云 ECS 总入口：[云服务器 ECS](https://help.aliyun.com/zh/ecs/)
- App备案 FAQ：[App备案基础知识FAQ](https://help.aliyun.com/zh/icp-filing/basic-icp-service/support/basics-about-icp-filling-for-apps)

---

### 2.2 地域

推荐地域：

- 华东2（上海）

理由：

- 离你当前业务场景更近，华东访问延迟低
- 阿里云资源丰富，后续扩容方便
- 备案、短信、RDS、OSS 等配套齐全

---

### 2.3 ECS 应用服务器

推荐配置：

- 产品：ECS
- 实例规格族：`g8i`
- 实例规格：`ecs.g8i.large`
- CPU / 内存：2 vCPU / 8 GiB
- 镜像：Ubuntu 24.04 LTS 64位
- 系统盘：ESSD AutoPL，100 GB
- 公网：按流量计费，带宽峰值 100 Mbps
- 安全组：独立新建
- 网络：专有网络 VPC
- 可用区：任意可购买可用区，单可用区即可
- 台数：1 台

为什么是这个配置：

- 你这个项目的主要负载是 API、支付回调、地图接口转发、短信接口、后台管理
- 2C8G 对 Node / Deno / Java / Go / Python 这类后端都够用
- 比 2C4G 更稳，日志、Nginx、PM2、Docker、管理面板一起跑也不容易顶满
- 100 GB 系统盘足够放系统、Docker、日志、构建产物、备份脚本

官方实例规格参考：
- ECS 实例概述：[实例概述](https://help.aliyun.com/zh/ecs/user-guide/overview-52)
- g8i / c8i 规格族说明：[ECS实例规格族的特点和指标数据](https://help.aliyun.com/zh/ecs/user-guide/overview-of-instance-families)

---

### 2.4 数据库

推荐配置：

- 产品：阿里云 RDS PostgreSQL
- 系列：高可用版
- 规格：2 vCPU / 4 GiB
- 存储：ESSD 100 GB
- 部署：与 ECS 同地域
- 访问方式：仅内网访问，不开公网白名单
- 备份：开启自动备份，保留 7 到 14 天

为什么这样配：

- 你当前 Supabase 用的是 PostgreSQL 体系，迁移到 RDS PostgreSQL 成本最低
- 高可用版比基础版更适合正式运营
- 2C4G + 100GB 足够支撑项目早期的订单、用户、聊天、帖子、需求、支付记录

官方说明：
- RDS PostgreSQL 产品系列说明：[RDS PostgreSQL产品系列及各系列适用场景](https://help.aliyun.com/zh/rds/apsaradb-rds-for-postgresql/product-editions/)

---

### 2.5 对象存储

推荐配置：

- 产品：OSS
- Bucket 类型：标准存储
- 地域：与 ECS / RDS 相同
- 用途：
  - 用户头像
  - 帖子图片
  - 招募/自荐图片
  - 后续聊天图片、审核材料、导出文件

要求：

- Bucket 私有读写
- 由后端生成临时访问地址，或根据业务开放指定路径的公共读

---

### 2.6 域名

推荐准备：

- 1 个主域名，例如：`yourapp.com`
- 解析规划：
  - `api.xxx.com`：后端 API
  - `admin.xxx.com`：后台管理
  - `static.xxx.com`：静态资源或 OSS 绑定域名

官方入口：
- 域名服务总入口：[域名注册交易解析管理](https://help.aliyun.com/zh/dws/)
- 域名管理：[域名管理](https://help.aliyun.com/zh/dws/user-guide/domain-name-management/)

---

### 2.7 短信服务

推荐：

- 产品：阿里云短信服务
- 用途：手机号验证码、订单通知、审核通知

说明：

- 现在测试阶段可以先把接口接好
- 正式使用前需要短信签名和模板审核

---

### 2.8 备案要求

本项目按中国内地正式部署处理，因此按“必须备案”执行。

必须完成：

- ICP备案
- App备案
- 有网页后台公开访问时，继续按要求处理公安联网备案

原因：

- 阿里云官方说明，使用中国内地服务器提供网站/App服务，必须先备案
- App 后台如果部署在阿里云中国内地节点，也需要做 App 备案

官方说明：
- 什么是ICP备案：[什么是ICP备案](https://help.aliyun.com/zh/icp-filing/basic-icp-service/product-overview/what-is-an-icp-filing)
- 备案服务器检查：[ICP备案前的服务器及接入信息确认排查](https://help.aliyun.com/zh/icp-filing/basic-icp-service/user-guide/icp-filing-server-access-information-check)
- 备案流程 FAQ：[域名、企业和服务器备案的条件和备案流程](https://help.aliyun.com/zh/icp-filing/basic-icp-service/support/for-the-record-process-faq)
- App备案 FAQ：[App备案基础知识FAQ](https://help.aliyun.com/zh/icp-filing/basic-icp-service/support/basics-about-icp-filling-for-apps)
- App 备案快速入门：[App ICP备案与公安联网备案操作流程](https://help.aliyun.com/zh/icp-filing/basic-icp-service/getting-started/quick-sta-rt-for-icp-filing-for-personal-app)

---

## 3. 最终配置文件

下面这份就是我建议你照着买的“正式第一版”配置单。

```yaml
project: banyixia
stage: test_to_initial_production

cloud_vendor: aliyun
region: cn-shanghai

account:
  type: enterprise_verified

network:
  vpc: create_new
  vpc_cidr: 172.16.0.0/16
  vswitch_cidr: 172.16.1.0/24
  security_group: create_new

ecs:
  product: ECS
  instance_family: g8i
  instance_type: ecs.g8i.large
  cpu: 2
  memory_gb: 8
  os: Ubuntu_24_04_64
  quantity: 1
  system_disk:
    type: ESSD_AutoPL
    size_gb: 100
  public_network:
    billing: pay_by_traffic
    max_bandwidth_mbps: 100
  login_method: key_pair_preferred

rds:
  product: RDS_PostgreSQL
  edition: high_availability
  cpu: 2
  memory_gb: 4
  storage_type: ESSD
  storage_gb: 100
  public_access: false
  backup_days: 7

oss:
  product: OSS
  bucket_class: standard
  access: private

domain:
  required: true
  records:
    - api
    - admin
    - static

sms:
  provider: aliyun_sms
  required: true

filing:
  icp_required: true
  app_filing_required: true
  public_security_filing_required: true

ports:
  inbound:
    - port: 22
      source: fixed_admin_ip_only
    - port: 80
      source: 0.0.0.0/0
    - port: 443
      source: 0.0.0.0/0
  outbound:
    - all_required_business_traffic

do_not_buy_now:
  - ALB
  - Redis
  - Kubernetes
  - second_ecs
  - public_rds
```

---

## 4. 申请与购买步骤

以下步骤按“现在就开始买”的顺序写。

### 第一步：准备账号

1. 注册阿里云账号。
2. 完成企业实名认证。
3. 开启控制台访问权限。

---

### 第二步：购买域名

1. 登录阿里云域名控制台。
2. 搜索你要的域名。
3. 选择 `.com` 优先。
4. 完成购买。
5. 暂时不要乱配解析，等 ECS 公网 IP 出来后再配。

官方入口：
- [域名注册交易解析管理](https://help.aliyun.com/zh/dws/)

---

### 第三步：购买 ECS

1. 打开 ECS 控制台购买页。
2. 地域选择：华东2（上海）。
3. 网络类型选择：专有网络 VPC。
4. 新建 VPC：`172.16.0.0/16`
5. 新建交换机：`172.16.1.0/24`
6. 实例规格族选择：`g8i`
7. 实例规格选择：`ecs.g8i.large`
8. 镜像选择：Ubuntu 24.04 LTS 64位
9. 系统盘选择：ESSD AutoPL 100GB
10. 公网带宽选择：按流量计费，100Mbps 上限
11. 安全组：新建一个安全组
12. 登录方式：优先密钥对
13. 完成购买

官方入口：
- [云服务器 ECS](https://help.aliyun.com/zh/ecs/)
- [实例概述](https://help.aliyun.com/zh/ecs/user-guide/overview-52)

---

### 第四步：配置安全组

创建完成后，只保留这几条入方向规则：

- 22：只允许你的固定公网 IP
- 80：允许 `0.0.0.0/0`
- 443：允许 `0.0.0.0/0`

禁止：

- 不要把 22 端口对全网开放
- 不要开放 5432 到公网

官方说明：
- [使用安全组](https://help.aliyun.com/zh/ecs/user-guide/start-using-security-groups)
- [安全组规则](https://help.aliyun.com/zh/ecs/user-guide/security-group-rules/)

---

### 第五步：购买 RDS PostgreSQL

1. 打开 RDS PostgreSQL 购买页。
2. 地域选择与 ECS 一致：华东2（上海）
3. 版本选择 PostgreSQL
4. 系列选择：高可用版
5. 规格选择：2C4G
6. 存储选择：ESSD 100GB
7. 网络接入：放在和 ECS 同一个 VPC
8. 不开公网访问
9. 开启自动备份
10. 完成购买

官方说明：
- [RDS PostgreSQL产品系列及各系列适用场景](https://help.aliyun.com/zh/rds/apsaradb-rds-for-postgresql/product-editions/)

---

### 第六步：购买 OSS

1. 创建 Bucket。
2. 地域选择与 ECS 一致。
3. 存储类型选择标准存储。
4. 读写权限先设为私有。

用途：

- 替代 Supabase Storage

---

### 第七步：做备案

这一步按必须执行处理。

顺序：

1. 先确认 ECS 是中国内地节点，且满足备案要求。
2. 在阿里云备案系统发起 ICP 备案。
3. 填写主体信息、网站/App 信息、接入信息。
4. App 按 App 备案流程单独完成。
5. 备案通过后，再把域名正式解析到 ECS。

备案前需要准备：

- 企业主体资料
- 法人或负责人身份资料
- 域名
- 已购买的中国内地 ECS
- App 基本信息

官方说明：
- [ICP备案前的服务器及接入信息确认排查](https://help.aliyun.com/zh/icp-filing/basic-icp-service/user-guide/icp-filing-server-access-information-check)
- [网站域名ICP备案时需要哪些资料](https://help.aliyun.com/zh/icp-filing/basic-icp-service/user-guide/required-materials)
- [在ICP备案时填写网站或App的接入信息](https://help.aliyun.com/zh/icp-filing/basic-icp-service/user-guide/fill-in-the-access-information-of-website-app)

---

## 5. 端口与安全策略

ECS 安全组入方向只保留：

- 22：你的固定办公 IP
- 80：公网
- 443：公网

应用内部建议：

- Nginx 对外监听 80/443
- 后端程序只监听 `127.0.0.1:3000` 或 `127.0.0.1:8080`
- PostgreSQL 不装在 ECS 本机
- 数据库只走 RDS 内网

---

## 6. 当前项目对应的部署落点

这个项目迁到阿里云后，建议职责这样分：

- Flutter App：继续作为客户端
- ECS：
  - 后端 API
  - 支付下单接口
  - 支付回调
  - 短信发送接口
  - 地图搜索/逆地理代理接口
  - 后台管理系统
- RDS PostgreSQL：
  - 用户
  - 地陪
  - 订单
  - 聊天
  - 帖子
  - 需求
  - 支付记录
- OSS：
  - 图片
  - 附件
  - 头像

---

## 7. 结论

当前项目最合适的阿里云首版采购结论只有一套：

- ECS：`ecs.g8i.large`，2C8G，100GB 系统盘
- RDS PostgreSQL：高可用版，2C4G，100GB
- OSS：标准存储，私有 Bucket
- 地域：华东2（上海）
- 必做：域名、ICP备案、App备案、安全组收敛、短信服务
- 当前不买：ALB、Redis、K8s、第二台 ECS

这套方案足够你把当前项目从 Supabase 过渡到阿里云，并且不会在一开始就把运维复杂度拉得太高。
