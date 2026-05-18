# 项目部署与第三方能力接入执行文档

## 一、统一实施标准

本项目统一按以下标准实施，不采用分支方案。

1. 云平台  
   阿里云

2. 服务器  
   `ECS 云服务器 1 台`  
   配置标准：`4 vCPU / 8 GB RAM / 100 GB ESSD / 5M 固定带宽 / Ubuntu 22.04 LTS`

3. 数据库  
   `阿里云 RDS PostgreSQL 1 个实例`  
   配置标准：`PostgreSQL 16 / 2 vCPU / 4 GB RAM / 100 GB ESSD`

4. 部署结构  
   `Flutter App -> Nginx -> 后端 API -> RDS PostgreSQL`

5. 第三方能力  
   - 支付：支付宝 `APP支付`
   - 地图：高德 `Web 服务 API + Android 定位 SDK`
   - 短信：阿里云 `短信服务`

6. 地域  
   统一使用中国内地地域，建议 `华东1（杭州）`

7. 域名与 HTTPS  
   必须配置正式域名与 HTTPS

## 二、关键词解释

1. `ECS`  
   阿里云弹性云服务器，相当于一台可远程登录的 Linux 服务器。  
   官方入口：https://help.aliyun.com/zh/ecs/

2. `RDS PostgreSQL`  
   阿里云托管数据库服务，负责 PostgreSQL 安装、备份、监控、可用性。  
   官方文档：https://help.aliyun.com/zh/rds/apsaradb-rds-for-postgresql/create-an-apsaradb-rds-for-postgresql-instance-1

3. `VPC`  
   云上的私有网络。ECS 和 RDS 在同一个 VPC 内可走内网通信，延迟低、无需暴露数据库公网。

4. `安全组`  
   云服务器的网络访问规则。决定哪些端口可以被外部访问。  
   官方文档：https://help.aliyun.com/zh/ecs/user-guide/security-group-overview

5. `域名解析`  
   把域名指向服务器公网 IP。  
   官方文档：https://help.aliyun.com/zh/dns/add-record/

6. `HTTPS / SSL证书`  
   让域名通过加密方式访问，支付回调、正式接口、浏览器访问都要求 HTTPS。  
   官方文档：https://help.aliyun.com/zh/ssl-certificate/

7. `ICP备案`  
   中国内地服务器对外提供网站或 App 后台服务时，必须向工信部完成备案。  
   官方说明：https://help.aliyun.com/document_detail/61819.html

8. `App备案`  
   中国大陆上架和运营的 App，使用中国内地云资源作为后台时，需要完成 App 备案。  
   官方文档：  
   https://help.aliyun.com/zh/icp-filing/basic-icp-service/getting-started/quick-sta-rt-for-icp-filing-for-personal-app  
   https://help.aliyun.com/zh/icp-filing/basic-icp-service/support/basics-about-icp-filling-for-apps

9. `SHA1`  
   Android 签名证书摘要。高德 Android Key 绑定时必须填写。

10. `AccessKey`  
    阿里云 API 身份凭证，包含 `AccessKey ID` 和 `AccessKey Secret`。

## 三、阿里云服务器与数据库申请步骤

目标结果：获得 1 台 ECS、1 个 RDS PostgreSQL、1 个域名、1 张 SSL 证书，并完成备案。

### 1. 注册并实名认证阿里云账号

入口：https://www.aliyun.com/

操作：
- 打开阿里云官网并登录
- 完成个人或企业实名认证
- 实名完成后进入控制台

### 2. 购买 ECS

官方文档：https://help.aliyun.com/zh/ecs/user-guide/create-instances//

操作：
- 进入 ECS 控制台
- 点击“创建实例”
- 计费方式选择包年包月
- 地域选择 `华东1（杭州）`
- 网络选择默认专有网络 `VPC`
- 操作系统选择 `Ubuntu 22.04 LTS`
- 实例规格选择 `4核8G`
- 系统盘选择 `ESSD 100GB`
- 公网带宽选择 `固定带宽 5M`
- 安全组选择“新建安全组”
- 设置登录凭证，方式选“密码”
- 设置服务器密码
- 确认订单并购买

### 3. 配置 ECS 安全组

官方文档：https://help.aliyun.com/zh/ecs/user-guide/security-group-overview

操作：
- 进入 ECS 实例详情
- 进入“安全组”
- 添加入方向规则
- 开放端口：`22`、`80`、`443`
- 协议选 `TCP`
- 授权对象临时可填 `0.0.0.0/0`
- 保存

### 4. 通过 Workbench 登录 ECS

官方文档：  
https://help.aliyun.com/zh/ecs/user-guide/workbench-overview//  
https://help.aliyun.com/document_detail/25425.html

操作：
- 在 ECS 控制台选择实例
- 点击“远程连接”
- 选择 `Workbench`
- 输入 root 用户和密码
- 登录成功后进入 Linux 终端

### 5. 初始化 ECS 环境

登录后执行：

```bash
apt update && apt upgrade -y
apt install -y curl git unzip nginx
timedatectl set-timezone Asia/Shanghai
mkdir -p /srv/app
systemctl enable nginx
systemctl start nginx
```

### 6. 购买 RDS PostgreSQL

官方文档：https://help.aliyun.com/zh/rds/apsaradb-rds-for-postgresql/create-an-apsaradb-rds-for-postgresql-instance-1

操作：
- 进入 RDS 控制台
- 选择 PostgreSQL
- 计费方式选择包年包月
- 地域选择 `华东1（杭州）`
- 网络选择与 ECS 相同的 `VPC`
- 引擎版本选择 `PostgreSQL 16`
- 实例规格选择 `2核4G`
- 存储选择 `ESSD 100GB`
- 数据库端口保留 `5432`
- 确认并购买

### 7. 创建 RDS 账号和数据库

官方文档：https://help.aliyun.com/zh/rds/apsaradb-rds-for-postgresql/create-a-database-and-an-account-on-an-apsaradb-rds-for-postgresql-instance

操作：
- 打开 RDS 实例详情
- 创建高权限账号，例如 `app_admin`
- 设置强密码
- 创建数据库，例如 `companion_app`
- 授权该账号访问该数据库

### 8. 配置 RDS 白名单

操作：
- 打开 RDS 实例
- 找到“白名单与安全组”
- 添加 ECS 所在 VPC 网段或 ECS 私网 IP
- 保存

要求：RDS 不开放公网访问，只允许 ECS 内网访问。

### 9. 购买域名

操作：
- 在阿里云域名控制台购买 1 个域名
- 域名完成实名认证
- 域名状态变为可用

### 10. 添加域名解析

官方文档：https://help.aliyun.com/zh/dns/add-record/

操作：
- 进入云解析 DNS
- 进入域名解析设置
- 添加 `A` 记录
- 主机记录填 `@`
- 记录值填 ECS 公网 IP
- 再添加一条 `www` 的 `A` 记录
- 记录值同样填 ECS 公网 IP

### 11. 申请 SSL 证书

官方文档：  
https://help.aliyun.com/zh/ssl-certificate/  
https://help.aliyun.com/zh/ssl-certificate/user-guide/apply-for-a-certificate

操作：
- 进入数字证书管理服务控制台
- 购买或申请证书
- 填写域名
- 完成域名验证
- 证书签发后下载 Nginx 版本证书文件

### 12. 在 ECS 上配置 HTTPS

证书上传到服务器后，在 Nginx 配置域名站点，监听 `443`，加载证书文件，并把 `80` 重定向到 `443`。

### 13. 提交 ICP 备案

官方文档：  
https://help.aliyun.com/zh/icp-filing/basic-icp-service/user-guide/overview/  
https://help.aliyun.com/document_detail/61819.html

操作：
- 进入阿里云备案系统
- 填写主体信息
- 填写域名信息
- 填写服务器信息
- 上传身份证明或营业执照
- 完成人脸核验
- 提交审核
- 获取备案号

### 14. 提交 App 备案

官方文档：https://help.aliyun.com/zh/icp-filing/basic-icp-service/getting-started/quick-sta-rt-for-icp-filing-for-personal-app

操作：
- 在备案系统中新增 App
- 填写 App 名称、图标、分类、下载地址、服务内容
- 绑定后台域名和服务器信息
- 提交审核
- 获取 App 备案编号

## 四、支付宝 APP支付接入步骤

官方入口：https://open.alipay.com/module/webApp  
开发工具：https://open.alipay.com/tool  
帮助中心：https://open.alipay.com/support/supportCenter.htm

### 1. 客户注册支付宝开放平台账号

- 打开支付宝开放平台
- 使用客户主体账号登录
- 完成实名认证和企业认证

### 2. 创建“网页/移动应用”

- 进入“网页/移动应用”
- 点击“前往创建”
- 填写应用名称、Logo、简介
- 创建完成后记录 `AppID`

### 3. 配置应用能力

- 在应用详情中开通 `APP支付`
- 填写应用包信息
- 填写回调域名

### 4. 生成应用密钥

方式统一采用支付宝开发者工具：
- 打开 https://open.alipay.com/tool
- 进入“密钥管理”
- 生成 `应用私钥` 和 `应用公钥`
- 私钥保存到服务器，仅开发方持有
- 公钥上传到支付宝开放平台

### 5. 获取支付宝公钥

- 上传应用公钥后
- 在应用密钥配置页查看 `支付宝公钥`
- 复制并交付开发方

### 6. 服务端实现下单接口

统一实现后端接口：`POST /api/payment/alipay/create-order`

后端流程：
- 接收订单号、金额、标题、用户信息
- 调用支付宝 `alipay.trade.app.pay`
- 生成订单字符串
- 返回给 App

### 7. App 拉起支付宝客户端

- Flutter 端请求后端下单接口
- 拿到 order string
- 调用支付宝 SDK 拉起支付

### 8. 配置异步通知地址

统一配置：`https://你的域名/api/payment/alipay/notify`

要求：
- 必须是公网可访问地址
- 必须是 HTTPS
- 必须由服务器处理验签和订单落库

### 9. 实现异步通知处理

后端收到通知后执行：
- 验签
- 校验订单号
- 校验金额
- 校验交易状态
- 更新订单为已支付
- 记录支付宝交易号
- 返回支付宝要求的成功响应

### 10. 实现主动查单接口

后端统一补充：`POST /api/payment/alipay/query`

用途：
- 用户支付完成但通知延迟时主动确认支付状态

### 11. 客户需要提供给开发方的资料及获取方式

- `AppID`  
  获取方式：支付宝开放平台应用详情页查看
- `支付宝公钥`  
  获取方式：密钥配置页查看
- 应用创建完成截图  
  获取方式：应用详情页截图
- 商户主体名称  
  获取方式：支付宝签约主体信息页查看
- 支付回调域名确认  
  获取方式：由客户提供正式域名

## 五、高德地图 API 接入步骤

官方入口：https://lbs.amap.com/api/webservice/summary  
创建 Key：https://amap.apifox.cn/doc-537183  
Android 定位 SDK Key 说明页：https://lbs.amap.com/api/android-location-sdk/guide/create-project/get-key

### 1. 客户注册高德开放平台开发者账号

- 登录高德开放平台
- 完成开发者注册

### 2. 创建应用

- 进入控制台
- 创建新应用
- 填写应用名称

### 3. 创建 `Web 服务 Key`

- 在应用下点击“添加新 Key”
- 服务平台选择 `Web服务 API`
- 提交
- 记录生成的 Key

用途：
- 输入提示
- 地理编码
- 逆地理编码

### 4. 创建 `Android 平台 Key`

- 在同一应用下再次点击“添加新 Key”
- 服务平台选择 `Android 平台 SDK`
- 填写 `应用名称`
- 填写 `Package Name`
- 填写 `调试版 SHA1`
- 填写 `发布版 SHA1`
- 提交
- 记录生成的 Android Key

用途：
- Android 设备定位
- 原生地图/定位 SDK 权限校验

### 5. 获取 Package Name

获取方式：
- 打开 Flutter 项目 [build.gradle.kts](/D:/APP/flutter_application_1/android/app/build.gradle.kts)
- 查看 `applicationId`

### 6. 获取调试版 SHA1

在项目 `android` 目录执行：

```powershell
.\gradlew signingReport
```

在输出中查找 `SHA1`

### 7. 获取发布版 SHA1

执行：

```powershell
keytool -list -v -keystore 你的keystore.jks -alias 你的alias
```

在输出中查找 `SHA1`

### 8. 服务端统一实现地图代理接口

后端统一实现：
- `GET /api/map/inputtips`
- `GET /api/map/geocode`
- `GET /api/map/regeo`

用途：
- 前端不直接暴露高德 Key
- 所有地图请求由服务器统一转发

### 9. 客户需要提供给开发方的资料及获取方式

- `Web 服务 Key`  
  获取方式：应用管理 -> Key 列表
- `Android SDK Key`  
  获取方式：应用管理 -> Key 列表
- `Package Name`  
  获取方式：由客户确认最终包名，或从项目配置读取
- `调试版 SHA1`  
  获取方式：`.\gradlew signingReport`
- `发布版 SHA1`  
  获取方式：`keytool -list -v -keystore ...`
- 高德控制台绑定成功截图  
  获取方式：Key 配置页截图

## 六、阿里云短信 API 接入步骤

官方入口：https://help.aliyun.com/zh/sms/getting-started/get-started-with-sms/  
控制台发送流程：https://help.aliyun.com/zh/sms/getting-started/use-sms-console-1/  
API 发送流程：https://help.aliyun.com/zh/sms/getting-started/use-sms-api/  
发送接口：https://help.aliyun.com/zh/sms/developer-reference/api-dysmsapi-2017-05-25-sendsms

### 1. 客户开通阿里云短信服务

- 登录阿里云控制台
- 进入短信服务
- 点击开通服务

### 2. 创建 AccessKey

- 进入阿里云 AccessKey 管理页
- 创建 `RAM 子账号`
- 给子账号授予短信服务权限
- 为子账号创建 `AccessKey ID` 与 `AccessKey Secret`
- 交付开发方

### 3. 申请短信资质

- 进入短信服务控制台
- 打开“资质管理”
- 按客户主体提交资质
- 等待审核通过

### 4. 申请短信签名

- 打开“签名管理”
- 新建签名
- 选择与资质一致的主体
- 提交审核
- 审核通过后记录签名名称

### 5. 申请短信模板

- 打开“模板管理”
- 新建验证码模板
- 例如内容可为“验证码 ${code}，5分钟内有效”
- 提交审核
- 审核通过后记录 `TemplateCode`

### 6. 绑定测试手机号

官方说明：https://help.aliyun.com/zh/sms/user-guide/send-test-messages-1/

操作：
- 进入“快速学习与测试”
- 添加测试手机号
- 保存

### 7. 服务端实现发送验证码接口

统一实现：
- `POST /api/sms/send-code`
- `POST /api/sms/verify-code`

### 8. 服务端发送验证码流程

- 接收手机号
- 生成 6 位验证码
- 写入数据库，保存手机号、验证码、过期时间、发送状态
- 调用 `SendSms`
- 发送成功后更新状态
- 返回发送结果

### 9. 服务端校验验证码流程

- 接收手机号和验证码
- 查询数据库中未过期、未使用记录
- 匹配成功后标记为已使用
- 生成登录态或登录 token

### 10. 客户需要提供给开发方的资料及获取方式

- 阿里云子账号  
  获取方式：客户创建 RAM 子账号
- `AccessKey ID` / `AccessKey Secret`  
  获取方式：子账号 AccessKey 管理页创建
- 短信签名名称  
  获取方式：短信服务控制台 -> 签名管理
- 短信模板 Code  
  获取方式：短信服务控制台 -> 模板管理
- 资质审核通过截图  
  获取方式：资质管理页截图
- 测试手机号绑定截图  
  获取方式：快速学习与测试页截图

## 七、开发方需要向客户索取的全部资料

### 1. 阿里云

- 阿里云主账号或具备购买权限的子账号
- 域名控制权限
- 证书服务控制权限
- 备案控制权限

### 2. 服务器与数据库

- ECS 购买完成截图
- ECS 公网 IP
- RDS 实例信息
- RDS 数据库名、账号名
- RDS 白名单配置截图

### 3. 支付宝

- `AppID`
- 支付宝公钥
- 应用创建截图
- 商户主体名称
- 支付产品开通截图

### 4. 高德

- `Web 服务 Key`
- `Android SDK Key`
- 调试版 SHA1
- 发布版 SHA1
- Package Name
- Key 绑定截图

### 5. 短信

- `AccessKey ID`
- `AccessKey Secret`
- 短信签名
- 模板 Code
- 资质、签名、模板审核通过截图

### 6. 合规与上架

- 营业执照或身份证明
- 用户协议
- 隐私政策
- 客服电话、客服邮箱
- App 名称
- App Logo
- App 图标
- App 启动图
- App 简介
- 应用分类说明

### 7. 业务规则

- 管理员账号归属
- 地陪审核规则
- 订单取消规则
- 退款规则
- 申诉处理规则

## 八、执行完成的判定标准

1. ECS 可通过域名 `https` 访问
2. RDS 可通过 ECS 内网连接
3. 域名解析生效
4. SSL 证书已部署
5. ICP备案号与 App备案号已取得
6. 支付宝可生成订单并接收异步通知
7. 高德地点搜索、地理编码、逆地理编码可用
8. 短信验证码发送与校验可用
9. Flutter App 只调用自有后端，不直接暴露第三方密钥

## 九、官方链接汇总

- 阿里云官网：https://www.aliyun.com/
- 阿里云 ECS：https://help.aliyun.com/zh/ecs/
- 创建 ECS 实例：https://help.aliyun.com/zh/ecs/user-guide/create-instances//
- 安全组概述：https://help.aliyun.com/zh/ecs/user-guide/security-group-overview
- ECS 远程连接：https://help.aliyun.com/document_detail/25425.html
- Workbench：https://help.aliyun.com/zh/ecs/user-guide/workbench-overview//
- RDS PostgreSQL 创建：https://help.aliyun.com/zh/rds/apsaradb-rds-for-postgresql/create-an-apsaradb-rds-for-postgresql-instance-1
- RDS 账号和数据库：https://help.aliyun.com/zh/rds/apsaradb-rds-for-postgresql/create-a-database-and-an-account-on-an-apsaradb-rds-for-postgresql-instance
- 域名解析：https://help.aliyun.com/zh/dns/add-record/
- SSL 证书：https://help.aliyun.com/zh/ssl-certificate/
- SSL 证书申请：https://help.aliyun.com/zh/ssl-certificate/user-guide/apply-for-a-certificate
- ICP备案：https://help.aliyun.com/document_detail/61819.html
- 备案前期准备：https://help.aliyun.com/zh/icp-filing/basic-icp-service/user-guide/overview/
- App备案：https://help.aliyun.com/zh/icp-filing/basic-icp-service/getting-started/quick-sta-rt-for-icp-filing-for-personal-app
- App备案FAQ：https://help.aliyun.com/zh/icp-filing/basic-icp-service/support/basics-about-icp-filling-for-apps
- 支付宝网页/移动应用：https://open.alipay.com/module/webApp
- 支付宝开发者工具：https://open.alipay.com/tool
- 支付宝帮助中心：https://open.alipay.com/support/supportCenter.htm
- 高德 Web 服务：https://lbs.amap.com/api/webservice/summary
- 高德创建 Key：https://amap.apifox.cn/doc-537183
- 高德 Android Key：https://lbs.amap.com/api/android-location-sdk/guide/create-project/get-key
- 阿里云短信服务：https://help.aliyun.com/zh/sms/getting-started/get-started-with-sms/
- 阿里云短信控制台发送：https://help.aliyun.com/zh/sms/getting-started/use-sms-console-1/
- 阿里云短信 API 发送：https://help.aliyun.com/zh/sms/getting-started/use-sms-api/
- 阿里云短信 SendSms：https://help.aliyun.com/zh/sms/developer-reference/api-dysmsapi-2017-05-25-sendsms
- 阿里云短信测试：https://help.aliyun.com/zh/sms/user-guide/send-test-messages-1/

