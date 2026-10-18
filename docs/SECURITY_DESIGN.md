# 安全设计说明（SECURITY DESIGN）

> 本文说明项目涉及的关键安全设计：证书与签名、信任存储、调试接口、进程守护、
> 更新流程、日志与网络行为。**文档描述与实际实现的差距会明确标注。**

## 1. 证书与代码签名

### 1.1 当前证书属性

| 属性 | 值 |
|---|---|
| Subject / Issuer | `CN=Codex Zh Launcher (Self-Signed), O=Codex Hanhua`（自签名） |
| 指纹（Thumbprint） | `76134CBD2706FD88D9FAD973CED58B3E32AC1DED`（本机稳定签名身份） |
| 有效期 | 2026-10-18 → 2036-10-18 |
| EKU | 代码签名 |
| Basic Constraints | 无 CA 标志（终端实体证书） |

用户可用以下命令核对：

```powershell
Get-AuthenticodeSignature .\Codex-Zh-Launcher-Windows-x64.exe |
    Format-List Status, SignerCertificate
Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert |
    Where-Object { $_.Subject -like '*Codex Zh Launcher*' } |
    Format-List Subject, Thumbprint, NotBefore, NotAfter, HasPrivateKey
```

### 1.2 为什么安装时导入证书

- **`CurrentUser\Root`**：让 Windows 把这张自签名证书视为信任锚，
  `Get-AuthenticodeSignature` 才能返回 `Valid`（否则状态是 `UntrustedRoot`）。
- **`CurrentUser\TrustedPublisher`**：让“发布者”显示为可信，减少“未知发布者”提示。

> ⚠️ 这是权宜方案：把终端实体证书当根 CA 使用，并不等价于公共 CA 签发的代码签名证书。
> 其他电脑若不导入证书，签名显示为 `UntrustedRoot`，程序仍可运行，但会被视为未受信任发布者。

### 1.3 信任策略与边界

- 证书仅用于**代码签名**（EXE 的 Authenticode），不用于加密、不用于 TLS、不签 MSIX。
- 私钥只存在于签名机器的当前用户证书存储，**从不提交到仓库**。
- 仓库内只提交公钥证书 `CodexZhLauncher.cer`。
- 卸载策略（阶段 5）：普通卸载**保留**证书；彻底卸载（`-Thorough`）按证书指纹
  从 `My` / `Root` / `TrustedPublisher` 精确删除，不按 Subject 模糊匹配、不清空存储区。
  详见 [`UNINSTALL.md`](UNINSTALL.md)。

### 1.4 签名身份策略（开发 vs 发布）

签名失败必须阻止部署：

- `sign.ps1` 在状态异常、签名者不符、指纹不符时**抛出异常**（退出码非 0）；
- `重新构建.ps1` 校验子进程退出码 + 独立复核 `Get-AuthenticodeSignature` 状态与指纹，
  任一失败即中止并保留旧版本（已验证：故障注入后旧 exe 哈希不变）；
- `打包安装版.ps1` 同样校验，失败即中止打包；
- CI 的签名校验步骤失败会使流水线失败。

| 场景 | 签名身份 | 说明 |
|---|---|---|
| 本地开发构建 | 开发者自签名证书 | 每次 `sign.ps1` 首次运行生成；仅本机信任 |
| 官方发布（本机） | 固定自签名身份（指纹 `76134CBD…`） | 由维护者在本机构建并签名后上传 Release |
| CI 自动构建 | **每次构建生成临时证书** | 仅用于验证构建产物；**CI 产物不视为官方签名发布物** |

> 阶段 2 计划：为官方发布增加固定的发布校验清单（哈希+签名+证书指纹），
> 并让 CI 明确只产出“开发验证产物”。
> 阶段 6 可考虑引入受控签名服务或公共 CA 证书（需成本）。

### 1.5 SmartScreen 说明（避免夸大）

- 自签名证书 ≠ 公共信任的代码签名证书。
- 导入证书**不保证** SmartScreen 警告消失；SmartScreen 依赖信誉体系，与 Authenticode 验证不是同一机制。
- 用户应先核对发布来源、哈希与签名者，再决定是否运行。

参考：
- <https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/code-signing-options>
- <https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation>

## 2. 调试接口（CDP / Inspector）

现状（源码依据 `LocalizationRuntime.cs` / `DevToolsClient.cs` / `AppActivation.cs`）：

- 启动 Codex 时传入 `--remote-debugging-address=127.0.0.1` 与随机端口，仅本机回环。
- 通过 CDP `Page.addScriptToEvaluateOnNewDocument` 注入 i18n 补丁，注入完成后由页面重载生效。
- 主进程 inspector 端口用于原生菜单补丁；该端口在当前 MSIX 版本连接失败，属已知情况（仅日志报错）。
- 实测（2026-10-19）：渲染调试端口仅监听 `127.0.0.1`，未监听 `0.0.0.0` / 局域网地址。
- **调试端口在 Codex 运行期间持续开放**：Chromium 无法在运行中关闭该端口。

阶段 4 实测与残余风险：
- [x] 确认仅回环监听（实测 `Get-NetTCPConnection`）
- [x] 端口在 Codex 退出后随进程释放（依赖进程生命周期）
- [x] 注入失败时会记录错误并继续（不崩溃）
- [ ] 缩短调试端口开放窗口（未实现，需评估替代方案）
- [ ] 注入失败时的回退行为；
- [ ] 缩短调试端口开放窗口；
- [ ] 确认没有监听非回环地址。

### 残余风险（如实记录）

Codex 由启动器启动并运行时，本机同用户权限的进程可连接该回环端口，进而读取/修改 Codex 渲染进程状态。
这是当前注入架构的固有代价，**不是已修复项**。缓解手段：仅回环绑定、随机端口、不额外常驻端口。
后续可选方向（未实现）：会话结束后重启 Codex 关闭端口（会丢失运行时注入）、评估 `--remote-debugging-pipe` 等替代方案。

## 3. 进程守护

- 自启项运行 `--supervise`：监督进程负责在守护退出后 3 秒内重启守护。
- 守护每 2 秒检测 Codex 进程，仅处理**当前 Windows 会话**中的进程（多用户隔离）。
- 归属控制：`owned-pid.txt` + `owned-applied.txt` + `launching.flag`，避免守护与工具界面互相抢占。
- **长会话保护**：运行超过 30 秒的实例不接管，避免强制重启导致未保存内容丢失。
- 用户主动关闭 Codex 后，守护不会主动重启 Codex（只接管“新的裸启动实例”）。

待测试补充（阶段 4）：连续点击、重复运行、注销/重启、更新过程中退出等场景。

## 4. 更新机制

- 一键重建：运行 `重新构建.ps1 -Update`，下载上游源码 → 套用 `overlay/` → 编译 → 签名 → 重启。
- **现状风险**：下载的是上游 `main` 分支 zip，未固定 commit，且未校验源码包哈希。
- 阶段 3 计划：固定上游 commit、记录 SHA、保留旧版本、构建失败自动回滚、补丁套用校验。

## 5. 日志

- 位置：`%LOCALAPPDATA%\CodexZhLauncher\logs\launcher.log`，超过 1MB 轮转为 `.old`。
- 内容：运行事件、版本检测结果、注入流程细节、异常堆栈。
- **已脱敏（v0.8.0 起）**：写入前把当前用户目录与 `C:\Users\<用户名>` 替换为 `%USERPROFILE%`；
  日志中不应再出现 Windows 用户名。仍可能包含安装路径、端口号、PID。
- 分享日志前仍建议自行检查并删除不需要的路径信息。
- 详见 [`PRIVACY_AND_NETWORK.md`](PRIVACY_AND_NETWORK.md)。

## 6. 网络访问清单

| 目标 | 目的 | 触发时机 | 传输内容 |
|---|---|---|---|
| `api.github.com/repos/shibaweidu/codex-desktop-zh/releases/latest` | 上游版本检测 | 登录后 15 秒 / 打开工具 5 秒后 | 仅 GET 请求，无用户数据 |
| `codeload.github.com/shibaweidu/codex-desktop-zh/zip/refs/heads/main` | 一键重建下载上游源码 | 用户点击「一键重建」或运行 `-Update` | 仅 GET 请求，无用户数据 |
| `uploads.github.com` / `api.github.com` | 仅维护者发布时使用 | 维护者本机发布脚本 | 发布文件 |

除上述之外，程序不发起网络请求；无遥测、无统计上报。

## 7. 权限与系统改动

| 项目 | 范围 |
|---|---|
| 管理员权限 | 不需要 |
| 注册表 | `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` 一项（开机自启） |
| 快捷方式 | 桌面 / 开始菜单 `Codex 中文版.lnk` |
| 证书 | 当前用户 `Root`、`TrustedPublisher`、`My` |
| 文件 | 程序目录、`%LOCALAPPDATA%\CodexZhLauncher` |
| Codex 本体 | **不修改**（不写入安装目录、不替换 app.asar） |

## 8. 未完成 / 待改进

- [x] 固定上游 commit 与源码哈希、失败回滚（阶段 3）
- [x] 发布物签名校验（CI）与发布清单/哈希清单（阶段 2）
- [x] CI 第三方 Actions 固定到 commit SHA（阶段 2）
- [x] 卸载时按指纹清理证书（阶段 5）
- [x] 调试端口行为实测与风险记录、日志脱敏（阶段 4）
- [ ] 第三方安全审查（阶段 6）

本文档随实现更新；**未完成项不会写成“已实现”**。
