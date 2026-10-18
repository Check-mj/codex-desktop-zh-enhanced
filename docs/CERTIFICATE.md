# 证书与信任配置说明（CERTIFICATE）

> 目标：让用户清楚知道——这是什么证书、为什么导入、影响哪些配置、如何核对、如何撤销。

## 1. 这是什么证书

本项目使用**自签名代码签名证书**给主程序和安装包签名：

| 属性 | 值 |
|---|---|
| Subject / Issuer | `CN=Codex Zh Launcher (Self-Signed), O=Codex Hanhua`（自签名） |
| 指纹（Thumbprint） | `76134CBD2706FD88D9FAD973CED58B3E32AC1DED`（官方发布身份，可能随证书更新变化） |
| 有效期 | 2026-10-18 → 2036-10-18 |
| 用途（EKU） | 代码签名（1.3.6.1.5.5.7.3.3） |
| Basic Constraints | 无 CA 标志（终端实体证书） |
| 私钥 | 只存在于签名机器的**当前用户**证书存储（`Cert:\CurrentUser\My`），**从不提交到仓库** |

> 仓库中只有公钥文件 `CodexZhLauncher.cer`，可以用它核对签名，但无法用它签名。

## 2. 为什么安装时要导入证书

安装程序会执行（仅当前用户，无需管理员）：

```powershell
certutil -user -addstore Root             CodexZhLauncher.cer
certutil -user -addstore TrustedPublisher CodexZhLauncher.cer
```

原因：

- **`Root`（受信任的根证书颁发机构）**：让 Windows 把这张自签名证书视为信任锚，
  `Get-AuthenticodeSignature` 才会返回 `Valid`；否则是 `UntrustedRoot`。
- **`TrustedPublisher`（受信任的发布者）**：让系统把该发布者标记为可信，减少“未知发布者”提示。

### 这个做法的局限（如实说明）

- 把**终端实体证书**当作根信任锚是权宜做法，不等价于公共 CA 签发的代码签名证书。
- 它只影响**当前 Windows 用户**的证书存储，不影响其他用户、也不改变系统级 Enterprise/机器级信任。
- 它**不能保证**消除 SmartScreen 警告——SmartScreen 依赖独立于 Authenticode 的信誉体系。
- 它不会让本证书具备签发其他证书的能力（证书本身无 CA 基本约束）。

## 3. 会修改哪些系统配置

| 位置 | 内容 | 影响范围 |
|---|---|---|
| `Cert:\CurrentUser\My` | 私钥 + 证书（仅签名机器） | 当前用户 |
| `Cert:\CurrentUser\Root` | 同指纹证书（信任锚） | 当前用户 |
| `Cert:\CurrentUser\TrustedPublisher` | 同指纹证书（可信发布者） | 当前用户 |

除此之外**不会**修改：机器级证书存储、组策略、Defender/SmartScreen 设置、Codex 安装目录。

## 4. 如何核对

```powershell
# 看签名与签名者
Get-AuthenticodeSignature .\Codex-Zh-Launcher-Windows-x64.exe |
    Format-List Status, SignerCertificate

# 看本机证书
Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert |
    Where-Object { $_.Subject -like '*Codex Zh Launcher*' } |
    Format-List Subject, Thumbprint, NotBefore, NotAfter, HasPrivateKey
```

也可以直接双击 `CodexZhLauncher.cer` 查看公钥信息。

## 5. 如何撤销 / 移除

### 方式一：彻底卸载（推荐）

```powershell
卸载.cmd -Thorough
```

会按**证书指纹**从 `My` / `Root` / `TrustedPublisher` 中删除对应证书，
不会按名称模糊匹配，也不会清空存储区。

### 方式二：手动删除

```powershell
$tp = (New-Object System.Security.Cryptography.X509Certificates.X509Certificate2('.\CodexZhLauncher.cer')).Thumbprint
Get-ChildItem Cert:\CurrentUser\My              | Where-Object { $_.Thumbprint -eq $tp } | Remove-Item -Force
Get-ChildItem Cert:\CurrentUser\Root            | Where-Object { $_.Thumbprint -eq $tp } | Remove-Item -Force
Get-ChildItem Cert:\CurrentUser\TrustedPublisher | Where-Object { $_.Thumbprint -eq $tp } | Remove-Item -Force
```

> 普通卸载**不会**删除证书；移除后程序仍可运行，但签名会显示为不受信任。

## 6. 换电脑使用

1. 运行安装程序（会自动导入证书），或手动运行 `导入证书.cmd`；
2. 未导入证书时签名状态可能是 `UntrustedRoot`，程序**仍可运行**，只是系统不认为发布者可信；
3. 若不愿导入证书，可自行用 `tools\verify-release.ps1` 核对哈希与签名者后决定是否使用。
