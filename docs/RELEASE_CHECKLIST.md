# 发布前检查清单（RELEASE CHECKLIST）

> 对应《安全与信任建设实施指南》第十节。任何关键项失败，不得作为正式版本发布。

## 1. 源码与构建

- [ ] Release 对应明确的 commit SHA（写入 Release 说明与发布清单）
- [ ] 上游源码版本可追溯（记录上游 commit SHA）
- [ ] 构建日志已保存（CI 运行链接或本机构建输出）
- [ ] 构建成功（`build.ps1` 退出码 0）
- [ ] 安装包内容完整（解压后含启动器、overlay、source、安装/卸载脚本）

## 2. 签名与完整性

- [ ] Authenticode 签名验证通过（`Get-AuthenticodeSignature` 无 `HashMismatch`）
- [ ] 若签名失败：构建/打包必须中止，不得产出未签名发布物（`sign.ps1` 抛异常 + 父脚本校验退出码/状态/指纹）
- [ ] 签名者与预期身份一致（`CN=Codex Zh Launcher (Self-Signed), O=Codex Hanhua`）
- [ ] 证书指纹正确（官方发布身份 `76134CBD2706FD88D9FAD973CED58B3E32AC1DED`）
- [ ] SHA-256 已生成并写入发布清单
- [ ] 发布文件与源码版本关联（同一 commit）
- [ ] 没有将私钥提交到仓库（仓库只允许出现 `CodexZhLauncher.cer` 公钥）
- [ ] CI 产物标记为开发验证产物，未被当作官方发布物

## 3. 功能与恢复

- [ ] 安装测试通过（默认目录 / 清理后残留符合预期）
- [ ] 启动器正常运行（版本号正确）
- [ ] 汉化功能正常（界面出现中文文案）
- [ ] 后台守护行为符合预期（自启、接管、长会话保护）
- [ ] 更新失败时旧版本仍可恢复（备份存在、回滚步骤可用）
- [ ] 卸载测试通过（自启项、快捷方式、日志、证书处理符合文档）
- [ ] 证书清理选项符合预期（默认保留、彻底卸载可选移除）

## 4. 文档与隐私

- [ ] README 与实际行为一致
- [ ] 已知限制已说明（MSIX only、接管延迟、自签名限制等）
- [ ] 网络访问说明准确（见 `docs/SECURITY_DESIGN.md` 网络访问清单）
- [ ] 日志不包含不必要的敏感信息（或已说明如何清理）
- [ ] Release 说明包含版本变化与校验信息（哈希、签名者）

## 5. 发布操作

- [ ] 从干净环境重新执行一次安装 + 卸载
- [ ] 生成发布清单（`tools/make-release-manifest.ps1`），区分“发布源码提交”与“实现改动提交”
- [ ] T9–T12 故障注入测试记录有效（脚本有变化则重跑，见 `docs/FUNCTIONAL_TESTS.md`）
- [ ] 记录构建时间、Windows 版本、Codex 版本
- [ ] 上传 Release 资产（安装包 EXE/ZIP、SHA256SUMS.txt、发布清单）
- [ ] 在 Release 说明中写明验证方法（链接 `docs/RELEASE_VERIFICATION.md`）
