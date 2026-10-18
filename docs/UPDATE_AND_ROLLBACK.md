# 更新与回滚说明（UPDATE & ROLLBACK）

本项目的“一键重建 / 上游同步”遵循以下安全流程（阶段 3）：

## 1. 上游版本固定

- 固定信息保存在 `tools/upstream-pin.json`：

  ```json
  {
    "repo": "shibaweidu/codex-desktop-zh",
    "version": "0.7.7",
    "commit": "82136f547a9bca582fc6d9ed9f37b6600de7e13a",
    "archive_sha256": "8F98051655A32F85F58121D1C465FC49B182ADE9F1542F098EAE0384F6E45FE4"
  }
  ```

- 更新时下载 `https://codeload.github.com/<repo>/zip/<commit>`（固定 commit，而不是 `main`）。
- 下载后校验 `archive_sha256`；不匹配立即中止，不覆盖现有版本。
- 需要显式升级上游时：运行 `重新构建.cmd -Update -Repin`（会查询最新 Release 并更新固定值与哈希）。

## 2. 构建与部署顺序（避免破坏现网）

1. 备份旧版本 exe 到 `backups\pre-update-<时间戳>\`
2. 编译到 `source\...\dist\`（不碰主程序）
3. **先签名 dist 产物**，签名失败则中止（主程序保持旧版本）
4. 签名成功后才替换主程序，并记录 `build-info.json`
5. 结束后输出构建信息（版本 / 哈希 / 签名者 / 上游 commit）

任何一步失败，主程序目录中的旧版本都不会被覆盖。

## 3. 构建信息记录（build-info.json）

每次重建都会在程序目录生成 `build-info.json`，包含：

- 构建时间
- 上游版本 / commit / 源码包 SHA-256
- 套用的 overlay 文件数量
- 产物路径、版本、SHA-256
- 签名状态、签名者、证书指纹

该文件用于追溯“这个 exe 是从哪个源码构建的”。

## 4. 回滚方式

**场景 A：刚更新完发现异常**

```powershell
# 1) 停止启动器
Get-Process -Name 'Codex-Zh-Launcher*' | Stop-Process -Force
# 2) 从备份恢复（时间戳取最近一次）
Copy-Item 'backups\pre-update-<时间戳>\Codex-Zh-Launcher-Windows-x64.exe' 'Codex-Zh-Launcher-Windows-x64.exe' -Force
# 3) 重新启动守护（如已配置开机自启，也可直接重启电脑）
Start-Process '.\Codex-Zh-Launcher-Windows-x64.exe' -ArgumentList '--supervise' -WindowStyle Hidden
```

**场景 B：回到已知稳定基线**

使用 `backups\v0.8.0-baseline-<sha>\` 中的 exe（见 `docs/SECURITY_BASELINE.md`），
或重新运行对应版本的安装包。

## 5. overlay 兼容性检查

同步上游时会检查 `overlay\*.cs` 在**新上游源码**中是否存在对应文件：

- 存在 → 正常覆盖；
- 不存在 → 提示“作为新增文件套用”（本项目新增的源文件属于此类）。

如果上游发生结构性变化（例如重命名了被修改的文件），覆盖后可能编译失败——
此时旧版本不受影响，按上节回滚即可，并等待本项目的适配提交。

## 6. 已知限制

- `-Repin` 需要访问 GitHub API（未认证时受速率限制）。
- 固定的是上游 Release 对应的 commit；上游对同一 tag 强推的情况理论上存在，但 SHA-256 校验会拦截内容变化。
