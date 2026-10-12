# 1.1.0 交付与验证状态

日期：2026-10-11。测试候选版，不能标为正式发行。

## 已通过

- Mac arm64 / x86_64 构建，合并 Universal App；严格代码签名完整性检查。已恢复原本地证书签名，指定要求绑定证书与应用标识；不能替代 Developer ID。
- AI 最终成功响应解析、解释 JSON 类型、Unicode 字素计数、模型列表读取与设置保存。
- Mac 两路大输出、超时、取消含子进程、标准输入；安装包 SHA256、失败与超时、任意 PATH 中 CLI 检测。
- Mac 剪贴板多格式恢复、取得复制序号后的新内容保留；双主题实际渲染，长文本完整保留并滚动。
- Mac 两种 Carbon 热键事件分别触发正确回调；生成的英文图片经过实际 Vision OCR，保留原文。
- 本人现有 CodeBuddy 登录下的 HY3 翻译、名词／句子／连贯段落解释，正文均在 100 字以内。
- Windows 可在 Mac 运行的核心检查：最终响应、解释类型、Unicode、设置、模型缓存、管道、超时、取消、100/101 字边界、同模型一次压缩、错误分类、升级失败恢复。
- Windows 自包含发布：.NET 运行库、OCR 原生库、中英文资源及微软运行库均在 payload 内；资源 SHA256 核对。

剪贴板保护的边界：两平台在模拟复制前和等待期间确认原应用仍在前台，读取后仅在复制序号未变时恢复。操作系统不能准确标明同一应用内两次同时复制的来源；不将单元检查说成任意并发复制均可保留。

## 尚未验证或不能完成

- Windows 实机：首次安装／升级／卸载、本人登录、热键冲突、UI Automation 与真实剪贴板格式、截图与 OCR、进程 Job Object、混合 DPI 多屏。当前没有 Windows 验证设备。
- Mac 干净账号自动安装、首次本人登录与权限、Intel 实际运行、多屏定位。
- Mac Developer ID Application / Installer 与 Apple 公证：没有对应证书，不能生成正式公证包。
- Windows Authenticode 签名：尚未提供证书。系统是否显示首次运行提示依设备而定。

## 文件

- Mac 应用：`Build/随手译.app`。
- Mac 测试安装包：`Dist/随手译-1.1.0-macOS-universal-TEST-UNSIGNED.pkg`。
- Windows 候选安装包：`Dist/Suishouyi-1.1.0-windows-x64-Setup.exe`。
- 包校验值：`Dist/SHA256SUMS.txt`；版本、架构与签名状态：`Dist/release-manifest.json`。

发给朋友前，先使用一台 Windows 和一台干净 Mac 完成上述操作检查；Mac 正式分发另需签名和公证。

## Windows 1.2.1 设置界面 · 2026-10-12

- 已完成：760×640 默认窗口、可调整大小、分区布局、双主题预览卡片、DPI 缩放与滚动布局；原有设置保存逻辑保留。
- 已通过：Windows 应用与自包含安装包构建、OCR 资源 SHA256 核对。
- 待实机确认：两种皮肤、窗口缩放、125%／150%／200% 显示缩放，以及模型、生成开关和快捷键操作。
- 本次只修改设置界面；首次使用窗口、官方扫码登录自动化和 Tencent 乱码仍见 `Windows/PENDING-FIXES.md`。
- 安装包：`Dist/Suishouyi-1.2.1-windows-x64-Setup.exe`。

## Windows 1.2.2 请求编码与截图标点 · 2026-10-12

- 已修改：进程标准输入明确使用无 BOM 的 UTF-8；翻译与解释提示要求处理清晰可识别内容，容忍边缘标点；保留原文及代码、URL、数学表达式中的有意义符号。
- 已通过：Windows 应用编译（0 警告、0 错误）、自包含安装包发布、OCR 资源 SHA256 核对。
- 待原 Windows 设备复查：`Windows`、`windows:`、`Tencent` 的翻译与解释，及中文、缩写、代码输入。未在 Windows 设备上验证乱码已消失。
- 安装包：`Dist/Suishouyi-1.2.2-windows-x64-Setup.exe`。
