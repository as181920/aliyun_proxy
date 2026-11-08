# AliyunProxy

阿里云服务的 Ruby/Rails 适配层。不同产品按服务目录和 namespace 隔离，例如短信使用
`AliyunProxy::Sms`，号码认证使用 `AliyunProxy::Pnvs`，百炼使用
`AliyunProxy::ModelStudio`。

## Model Studio OCR

`AliyunProxy::ModelStudio::Ocr::KeyInformationExtractionService` 封装百炼 Qwen-OCR 的
`key_information_extraction` 内置任务。调用方提供图片 URL 或 Base64 Data URL，以及自身业务字段的
`result_schema`；适配层只返回 `kv_result`，不把 HTTP 和供应商响应结构泄漏给业务 engine。
协议与字段结构以阿里云[Qwen-OCR API 参考](https://help.aliyun.com/zh/model-studio/qwen-vl-ocr-api-reference)为准。

阿里云 SDK 文档中的“本地文件路径”是 SDK 在调用进程内读取/上传文件的便利能力，不表示远端服务能读取
Rails 服务器的本地路径。此 engine 直接调用 DashScope HTTP：私有上传文件应先转为官方支持的 Base64
Data URL；已有安全公开地址的图片也可直接传 URL。接口不是 multipart 二进制上传。
Qwen-OCR 对 Base64 输入限制的是编码后的 Data URL 大小；调用方应预留 Base64 约三分之一的体积膨胀，
不能直接沿用公网 URL 模式的原文件上限。

```ruby
result = AliyunProxy::ModelStudio::Ocr::KeyInformationExtractionService.call(
  image: "data:image/jpeg;base64,...",
  result_schema: {
    "contact_name" => "名片持有人的姓名",
    "company_name" => "公司全称"
  }
)
```

生产环境配置：

- `aliyun_model_studio_api_key`：百炼 API Key；也兼容官方 `DASHSCOPE_API_KEY`。
- `aliyun_model_studio_workspace_id`：华北 2（北京）业务空间 ID，用于生成 workspace 专属域名。
- `aliyun_model_studio_api_base_url`：可选。其它地域时配置 API origin，例如
  `https://{WorkspaceId}.ap-southeast-1.maas.aliyuncs.com`（不要附加 `/api/v1`）；配置后无需
  `aliyun_model_studio_workspace_id`。推荐填写完整 HTTPS origin；只填写域名时会自动使用 HTTPS。
  首尾空白和末尾 `/` 会被规范化；HTTP、用户凭据、业务路径、query 和 fragment 均不接受。
- `aliyun_model_studio_ocr_model`：可选，默认 `qwen3.5-ocr`。

请求使用 3 秒连接超时和 30 秒读取超时。API Key 不进入业务参数、日志或响应。

## CAPTCHA Web/H5

`AliyunProxy::Captcha` 提供供应商验票、加密场景、浏览器绑定的短期挑战及统一页面。它不依赖身份或活动 engines；消费方负责一次性授权消费和最终登录/业务动作。浏览器协议入口为 `/api-docs/openapi.json`，页面为 `/captcha/challenges/:id`（均相对于实际 engine mount）。长期分层与接入契约统一维护在 EasyBiz GitLab Wiki 的 `products/captcha_verification`。

统一页面在 SDK 就绪并完成必要的环境采集等待后自动发起无痕验证，通过后经服务端验票自动回跳；是否需要追加交互由阿里云判断。SDK 必需的触发元素隐藏保留，页面通过官方实例方法调用，不模拟用户点击。关闭交互、加载或验票失败时提供手动重试，不自动循环；Turbo 离开时取消等待与请求。Auth 和活动消费方无需另外嵌入 SDK。

`aliyun_captcha_base_url` 可省略，回退使用 `app_frontend_base_url`，其 origin 自动允许回跳。`aliyun_captcha_return_origins` 为逗号分隔的 origin 白名单，支持 `https://code-li.com,https://*.code-li.com`：通配符仅匹配一个或多个完整子域名层级，不包含根域名；协议和有效端口必须一致，非默认端口需显式填写。仅对完全受控的子域名使用通配符，其他客户域名显式加入；配置项不能包含路径、query、fragment 或用户信息。返回 URL 自身的路径、query 和 hash 保留。生产只允许 HTTPS，开发环境的 localhost/127.0.0.1 HTTP 仍按具体端口匹配。

本地验证：`bin/rails test`、`bin/rails rubocop`、`node --test test/javascript/*.mjs`。GitLab CI 使用 Mise 和 `.ruby-version` / `.nvmrc`；测试数据库配置软链接自 Runner 服务器的 `/home/gitlab-runner/shared/configs/my_products/cms/aliyun_proxy/database.yml`，在 `RAILS_ENV=test` 下执行数据库准备与测试。

## Installation
Add this line to your application's Gemfile:

```ruby
gem "aliyun_proxy", git: "git@github.com:as181920/aliyun_proxy.git", branch: "main"
```

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
