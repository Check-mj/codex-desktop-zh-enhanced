# 第三方声明 / Third-Party Notices

## 上游项目

本项目的核心汉化逻辑、Windows/macOS 源码结构与构建脚本来自：

- **shibaweidu/codex-desktop-zh** — <https://github.com/shibaweidu/codex-desktop-zh>
- 许可证：MIT License
- Copyright (c) 2026 Codex Zh Launcher contributors

本项目对其进行修改与增强（后台守护、开机自启、自更新、安装包等），
修改部分同样以 MIT License 发布。

## 商标与归属

- Codex、ChatGPT、OpenAI 是 OpenAI 的商标/产品，本项目与 OpenAI 无任何关联。
- 本项目仅做本地界面语言的运行时增强，不修改 Codex 安装文件、不代理网络请求、不收集用户数据。

## 其他

- 构建使用 Windows 自带 .NET Framework 4.0 的 `csc.exe`，不引入第三方运行时。
- 代码签名使用项目自签名证书（`CodexZhLauncher.cer` 仅含公钥）。
