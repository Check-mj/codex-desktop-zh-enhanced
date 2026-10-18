# 更新与回滚说明（UPDATE & ROLLBACK）

本项目的“一键重建 / 上游同步”采用**临时目录构建 + 全部验证通过后部署**的安全流程。

## 1. 上游版本固定

固定信息保存在 `tools/upstream-pin.json`：

```json
{
  "repo": "shibaweidu/codex-desktop-zh",
  "version": "0.7.7",
  "commit": "82136f547a9bca582fc6d9ed9f37b6600de7e13a",
  "archive_sha256": "8F98051655A32F85F58121D1C465FC49B182ADE9F1542F098EAE0384F6E45FE4"
}
```

- 更新时下载 `https://codeload.github.com/<repo>/zip/<commit>`（固定 commit，而非 `main`）。
- 下载后校验 `archive_sha256`；不匹配立即中止。
- 需要升级上游时：`重新构建.cmd -Update -Repin`（查询最新 Release 并更新固定值与哈希）。

## 2. 安全构建流程

```
下载 zip（到临时文件）
   ↓ 失败 → 中止，现有源码/主程序不受影响
解压到临时目录
   ↓ 失败 → 中止
结构检查（build.ps1 / src / shared 必须存在）
   ↓ 失败 → 中止
在临时目录套用 overlay + 更新上游版本基线
   ↓
在临时目录编译
   ↓ 失败 → 中止
签名临时产物 + 独立复核（状态 Valid + 签名者指纹）
   ↓ 失败 → 中止
备份旧 exe → 同卷临时文件校验 → 原子替换主程序
   ↓ 失败 → 旧 exe 未改动
目录交换：旧源码移入 backups\source-pre-update-<时间戳>，新源码就位
   ↓ 失败 → 同时恢复旧 exe 与旧源码（原子恢复；失败会明确提示手动恢复路径）
```

关键点：

- **现有源码目录在构建/签名成功之前不会被删除或覆盖**；
- exe 使用同卷临时文件 + `File.Replace` 原子替换，避免复制中断留下不完整文件；
- 部署后半段（源码交换）失败时，会**同时回滚 exe 与源码**，而不是只恢复其中一项；
- 签名失败、构建失败、下载失败都不会影响旧版本；
- 只有全部验证通过，才会替换 exe 与源码；
- 每次构建都会生成 `build-info.json`（上游版本/commit、源码包哈希、产物哈希、签名指纹）。

## 3. 回滚方式

**场景 A：刚更新完发现异常**

```powershell
Get-Process -Name 'Codex-Zh-Launcher*' | Stop-Process -Force
Copy-Item 'backups\pre-update-<时间戳>\Codex-Zh-Launcher-Windows-x64.exe' 'Codex-Zh-Launcher-Windows-x64.exe' -Force
Start-Process '.\Codex-Zh-Launcher-Windows-x64.exe' -ArgumentList '--supervise' -WindowStyle Hidden
```

旧源码备份在 `backups\source-pre-update-<时间戳>\`，如需回滚源码直接把该目录移回
`source\codex-desktop-zh-main`。

**场景 B：回到已知稳定基线**

使用 `backups\v0.8.0-baseline-<sha>\` 或重新运行对应版本的安装包。

## 4. 已知限制

- `-Repin` 需要访问 GitHub API（未认证时有速率限制）。
- 固定的是 upstream Release 对应的 commit；SHA-256 校验可拦截内容变化。
- 源码旧备份会保留在 `backups\` 下，长期使用需自行清理。