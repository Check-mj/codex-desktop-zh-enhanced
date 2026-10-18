# 第三方审查范围与已知问题（AUDIT SCOPE）

> 本文用于支持外部审查：说明检查了什么、发现了什么、修复了什么、哪些还没覆盖。
> **本文不构成“绝对安全”的声明**；结论仅适用于注明的版本与测试环境。

## 1. 审查范围（建议第三方重点检查）

| 区域 | 文件 |
|---|---|
| 安装器 | `install.ps1` / `install.cmd` / `安装.cmd` |
| 卸载器与证书清理 | `uninstall.ps1` / `uninstall.cmd` / `卸载.cmd` / `卸载.ps1` |
| 证书生成、导入与删除 | `sign.ps1` / `导入证书.ps1` |
| 自更新与重建 | `重新构建.ps1` / `tools/upstream-pin.json` / `SelfUpdate` 相关源码 |
| CDP / Inspector 生命周期 | `source/.../src/AppActivation.cs`、`LocalizationRuntime.cs`、`DevToolsClient.cs` |
| 后台守护 | `source/.../src/Guard.cs`、`AutoStart.cs`、`LaunchOwnership.cs` |
| GitHub Actions 权限与固定版本 | `.github/workflows/build.yml`、`docs/DEPENDENCIES.md` |
| 发布物与源码对应关系 | `docs/RELEASE_MANIFEST-v0.8.0.md`、Release 说明 |

## 2. 已做过的检查（有记录）

- 证书属性审计：Subject/Issuer/Thumbprint/有效期/EKU/BasicConstraints，信任存储现状（`docs/SECURITY_BASELINE.md`）。
- 签名链路：本地构建签名、安装包签名、CI 签名验证步骤（失败会中止 CI）。
- 调试端口：实测仅监听 `127.0.0.1`；端口生命周期与风险记录（`docs/RUNTIME_BEHAVIOR.md`）。
- 进程守护：启动、重复启动、用户关闭、强杀恢复、长会话保护等场景实测。
- 日志：写入前脱敏 `%USERPROFILE%` / `C:\Users\<用户名>`（`AppLog.cs`）。
- 网络：源码审计 + 网络访问清单（`docs/PRIVACY_AND_NETWORK.md`）。
- 更新：上游固定 commit + 源码包 SHA-256 校验 + 旧版本备份 + 失败不覆盖（`docs/UPDATE_AND_ROLLBACK.md`）。
- 卸载：普通/彻底两种模式、按指纹删证书、DryRun 演练（`docs/UNINSTALL.md`）。

## 3. 在安全建设过程中发现并修复的问题

| # | 问题 | 影响 | 修复 |
|---|---|---|---|
| 1 | CI 中 `certutil` 导入根证书弹出交互确认 | CI 卡死 | CI 跳过证书信任导入，仅签名 |
| 2 | CI 工作流步骤名包含 `: ` 导致 YAML 解析失败 | 流水线 0 job 失败 | 重写步骤名 |
| 3 | CI 签名带时间戳导致 `UnknownError` | 签名校验失败 | CI 不加时间戳，校验签名者身份 |
| 4 | 守护在“Codex 已在运行时启动”的情况下仍保留自动启动标记 | 用户关闭 Codex 后被自动重开 | 启动时检测到实例即设置 `autolaunch.skipped` |
| 5 | 旧 `卸载.cmd` 以 ASCII 保存中文路径导致乱码 | 卸载入口可能失效 | 改为 ASCII 脚本名 + `uninstall.ps1` |
| 6 | 打包脚本版本号写死，与程序版本不一致 | 发布物命名与版本不符 | 从 `AppInfo.cs` 自动读取 |
| 7 | 日志包含 Windows 用户名路径 | 隐私泄露风险 | 写入前脱敏 |

## 4. 已知未覆盖 / 未解决

- **调试端口在 Codex 运行期间持续开放**：本机同用户进程可连接（架构固有限制，已记录未解决）。
- **未做独立第三方安全审计**：本仓库的检查是自证性质。
- **未做整机重启验证**：自启动链路的重启场景仅有逻辑推断。
- **未做抓包验证**：网络行为结论基于源码审计与日志。
- **SmartScreen 行为**：自签名证书无法保证消除警告。
- **未测试其他 Windows 版本/多用户并发场景**。

## 5. 如何参与审查

- 在 Issues 中提交“安全审查”类 issue，注明审查范围与依据版本。
- 提供可复现步骤与日志（请先自行删除个人路径信息）。
- 我们会在修复后更新本文档的“问题与修复”表，并注明未解决项。
