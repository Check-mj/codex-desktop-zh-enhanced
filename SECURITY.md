# 安全说明 / Security Policy

## 报告安全问题

请通过仓库 Issues 反馈，并注明版本号与复现步骤。
涉及敏感信息（如可被利用的细节）时，请先只提交概述，我们会约定后续沟通方式。
请勿在公开 Issue 中粘贴完整的个人日志路径、账号信息或证书私钥。

当前支持的安全更新版本：**v0.8.x**。

## 程序做了什么

- 通过本地回环调试端口（CDP / inspector）向 Codex 注入前端补丁，开启官方中文界面。
- 不修改 Codex 安装目录、不替换 `app.asar`、不代理网络流量。
- 只写入当前用户的注册表项（开机自启）与 `%LOCALAPPDATA%\CodexZhLauncher` 下的日志/状态文件。
- 网络访问仅限：GitHub 版本检查、一键重建时下载上游源码（详见
  [`docs/SECURITY_DESIGN.md`](docs/SECURITY_DESIGN.md) 的网络访问清单）。

## 证书与签名（请如实理解）

- 主程序与安装包使用**项目自签名证书**签名，不是公共 CA 证书。
- 安装程序会把该证书导入当前用户的 `Root` 与 `TrustedPublisher`，
  目的是让 Windows 将该签名显示为有效/可信发布者。
- 这**不等于**公共信任的代码签名证书，也**不能保证**消除 SmartScreen 警告；
  SmartScreen 使用独立于 Authenticode 的信誉机制。
- 仓库内仅包含公钥证书 `CodexZhLauncher.cer`，**不含私钥**。
- 官方发布签名身份指纹：`76134CBD2706FD88D9FAD973CED58B3E32AC1DED`（本机维护者证书）。
- CI 自动构建产物由每次构建生成的临时证书签名，**不属于官方签名发布物**。

## 如何验证发布文件

见 [`docs/RELEASE_VERIFICATION.md`](docs/RELEASE_VERIFICATION.md)，或运行：

```powershell
powershell -File tools\verify-release.ps1 -Path .\xxx.exe `
  -ExpectedThumbprint 76134CBD2706FD88D9FAD973CED58B3E32AC1DED
```

## 风险提示

- 本工具会关闭并重启 Codex 进程以完成注入。守护模式接管“裸启动”实例时，
  若你在启动后极短时间内输入了未保存内容，理论上有丢失风险；
  运行超过 30 秒的实例不会被强杀。
- 自签名程序可能触发杀毒软件误报，请自行判断是否加入白名单。
- 非官方项目，与 OpenAI 无关联，使用风险自负。

## 设计说明与基线

- 安全设计：[`docs/SECURITY_DESIGN.md`](docs/SECURITY_DESIGN.md)
- 安全基线（版本、哈希、证书、测试记录）：[`docs/SECURITY_BASELINE.md`](docs/SECURITY_BASELINE.md)
- 第三方审查范围与已知问题：[`docs/AUDIT_SCOPE.md`](docs/AUDIT_SCOPE.md)
