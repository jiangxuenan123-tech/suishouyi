# Windows 构建

本次使用 macOS arm64，官方 .NET SDK 10.0.401；临时路径 `/private/tmp/suishouyi-dotnet`。SDK 下载 SHA512 已与微软 10.0 release metadata 核对，无全局安装或 sudo。

构建命令：

```sh
bash Distribution/build-windows.sh
```

其他构建机通过 `SUISHOUYI_DOTNET` 指定 .NET 10 SDK 的 dotnet 可执行文件。脚本依次运行核心检查、发布 Windows x64 自包含应用、验证 OCR 资源与原生 DLL、生成嵌入 zip、自包含发布 Setup.exe。首次恢复构建引用需要联网。核心检查在 Mac 上使用系统 Python 作为受控 CLI 子进程；不访问真实账号。

45 秒真实超时检查：

```sh
DOTNET_CLI_HOME=/private/tmp/suishouyi-dotnet-home NUGET_PACKAGES=/private/tmp/suishouyi-nuget /private/tmp/suishouyi-dotnet/dotnet run --project Windows/Checks -c Release -- --full-timeout
```

产物：`Dist/Suishouyi-1.1.0-windows-x64-Setup.exe`。应用目标：`net10.0-windows`、`win-x64`，PerMonitorV2；运行时与 OCR 随包，普通使用者无需 SDK、Node 或手输命令。

依赖固定版本、官方来源及真实 SHA256：`Windows/dependencies.json`。第三方许可：`Windows/THIRD-PARTY-NOTICES.md` 与 `Windows/App/Resources/Licenses/`。CodeBuddy 原生 CLI 在用户电脑官方下载校验，安装包不包含账号资料。

安装位置：`%LOCALAPPDATA%\Programs\Suishouyi`。偏好、模型缓存、独立 CLI 工作目录与应用管理的 CodeBuddy：`%LOCALAPPDATA%\Suishouyi`；升级／卸载保留。安装器使用临时 staging 和 previous 目录：完成前失败恢复旧目录，previous 在下一次安装前清理，卸载移除。

Setup.exe 未使用 Authenticode 签名。Mac 交叉编译不能验证 Windows UI、系统 API、首次登录及安装流程，发布前必须完成实机清单。
