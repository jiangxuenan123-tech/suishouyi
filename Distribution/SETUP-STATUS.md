# Mac 设置与安装包状态

版本：1.1.0。源文件：Sources/SetupCoordinator.swift、Sources/DependencyInstaller.swift。

## 已实现

- CLI 探测：安装向导与 CodeBuddyClient.executable 共用 DependencyInstaller 候选目录，包含 PATH；避免复用成功后翻译找不到同一组件。
- 首次窗口：自动检查、复用或下载官方原生 CodeBuddy；无 Node.js 要求。
- 兼容检查：仅向导安装步骤运行一次 --help，确认 print/output-format/tools/strict-mcp-config/no-session-persistence/model 参数。兼容才复用；不兼容的全局 CLI 不修改，改装自管二进制；旧自管文件替换时保留唯一 backup。常规请求不运行 --help。
- 安装位置：当前用户 `~/Library/Application Support/随手译/CodeBuddy/codebuddy`。不覆盖全局 CLI，不修改 shell 配置。
- 下载规则：读取官方 `latest`，下载对应 Darwin arm64/x86_64 压缩包，执行前必须匹配官方同版本 `checksums.txt` 的 SHA256。Rosetta 下选 arm64。
- 官方账号：按钮自动打开 Terminal `.command`，执行官方交互 `/login`。本人选择站点并完成浏览器授权；应用不读 token、不复制账号数据。
- 账号可用性：仅点击「检查并继续」后，通过官方 `--print` 发送一次很短的已保存模型请求。成功才显示可用，并显示选字、快捷键、复制的演示；失败提示登录、网络与额度，不把网络错误误标成账号未登录。
- Mac 权限：分别直达辅助功能、屏幕录制设置，回到窗口重新检查。系统要求重启时给出提示。
- 小接口：`@MainActor final class SetupCoordinator`，`show()`，`installCLI() async throws -> String`，`login()`。
- `Distribution/package-mac.sh`：检查 universal 与版本；安装至 `/Applications/随手译.app`；postinstall 以当前桌面用户启动。
- Developer ID Application/Installer 均存在时签名；指定已存储的 `NOTARYTOOL_PROFILE` 时公证。仅在 Accepted、stapler 和 Gatekeeper 均成功后标为 NOTARIZED。缺证书时明确标为 TEST-UNSIGNED，不假装正式分发。

## 已核实

2026-10-11，官方脚本：https://www.codebuddy.cn/cli/install.sh。

发布目录：https://acc-1258344699.cos.accelerate.myqcloud.com/@tencent-ai/codebuddy-code/releases。

官方 latest：2.164.0。压缩包包含 codebuddy 和 vendor/sandbox；随手译禁用工具，仅使用单文件 CLI，不使用 sandbox 工具。

- arm64 官方 SHA256：`ada40be6abbdbad7aec6d3a1dc4ce968b1e98e702bf9de48e857b6cb996f956d`。
- arm64 实际下载：59,972,935 bytes；本机计算 SHA256 与官方清单一致；解压执行 `--version` 返回 `2.164.0`。
- x86_64 官方 SHA256：`a815e7fbc6651701b282fd54036b38b0ab215c811f0c6bd5302dfab9e05d6091`；此项读取官方清单，尚未下载 Intel 包。
- 官方 SHA256 比对不等同于第三方 Apple 签名、公证或独立来源认证。
- 现有本机 CLI `2.160.0` 的帮助未列出独立 `auth status/login` 子命令；官方支持交互 `/login`。不假设不存在的命令。

## 检查结果

- SetupChecks：正确 SHA256 通过；错误、缺失、无效 SHA256 拒绝；只复用可执行文件；临时任意 PATH 目录中 CLI 可被翻译客户端复用，缺失候选抛出 missingCLI；兼容/不兼容 CLI 检查、仅自管替换和旧副本保留；stderr 隔离；非零退出和超时拒绝。
- SetupCoordinator / DependencyInstaller（引用现有 AppSettings、AIContract）：Swift 5 模式，SDK27.0，arm64 与 x86_64 macOS26.0 独立类型检查通过。
- package-mac.sh / postinstall：bash 语法检查通过；dependencies.json 解析通过。
- pkgbuild 打印 4 行 `write: Permission denied`，普通执行与提升权限执行均出现；最终返回 0。完整包已独立展开，所有文件逐字节匹配主构建，包内签名严格验证通过；尚未执行真实安装。
- Swift6.4 与旧 SDK26.5 有兼容问题；检查使用 SDK27.0 和独立临时 module cache。

## 最终安装包与验证边界

- 已生成 `Dist/随手译-1.1.0-macOS-universal-TEST-UNSIGNED.pkg`，未签名状态由 pkgutil 确认。
- 已 expand-full 核对 universal payload、版本 1.1.0、`/Applications/随手译.app`、`relocatable=false`、postinstall；包内二进制与主构建完全相同，codesign 严格验证通过。
- 最终主构建完成后已重新打包；包内 notice 与 dependencies 逐字节匹配 Distribution 源文件。
- 未操作本人首次登录、真实权限授权，不会代替用户确认。
- 尚未在干净 Mac/Intel Mac 上完成安装与首次使用。
- 本次证书查询 `0 valid identities`；最终主构建可另行检查本地证书；本地证书不能替代 Developer ID。

最终测试包：`随手译-1.1.0-macOS-universal-TEST-UNSIGNED.pkg`。大小：478,749 bytes。SHA256：`f9b8cf16cf80127874ade58420f23f1ffd2262bdbe1778d1cdfe6e8950dd9d5e`。

最终包内全部 5 个文件与最新 Build 逐字节一致；版本 1.1.0 / build 110 / macOS 26.0；arm64、x86_64 与 codesign strict 检查通过。未获得 Developer ID 签名和 Apple 公证。
