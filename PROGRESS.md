# 随手译开发记录 — 2026-10-11

用户已批准按体验建议开发。源项目：/Users/jiangxuenan/WorkBuddy/2026-09-14-08-24-53/mac-translator。

执行副本：work/suishouyi。备份：../suishouyi-before-20261011.tar.gz。

Ruling: 源项目无 Git / origin；采用独立文件副本，检查后同步；不创建远程、不声称提交推送。
Ruling: 翻译统一简体中文；本地回退相同目标；中文输入保持中文。成本：不提供中译英，符合当前英译中用途。
Ruling: 按最新“简单够用”要求，保留原生平台，直接实现必要职责；不增加无关通用层。
Pre-flight: 两平台共用解释 JSON status/kind/subject/body；结果保留 originalText/requestedModelId/actualModelId。模型切换影响下次请求；翻译/解释切换沿用原文，缓存只在当前窗口。
Pre-flight: 主题 refinedLight/techDark；首次 hy3/refinedLight；解释正文 <=100 Unicode 可见字符；压缩一次。

任务：核心规则与进程；Mac 输入与 UI；Windows 核心与 UI；依赖/安装；整体验证。

实现已完成：Mac 及 Windows 翻译/解释、输入、缓存、手动模型、双主题、取消、恢复、自动依赖与安装器。
Review: 独立只读审阅无 Critical；修复 Windows 条件恢复剪贴板、Mac PATH 查找、繁转简、压缩实际模型。复查原文保留和请求模型快照。
Verification: 参阅 Distribution/RELEASE-CHECKLIST.md。Mac 四个真实 hy3 样例通过。Windows 实机、干净/Intel Mac、混合 DPI 与正式签名仍待验证。
Deviation: 最小实现将 Swift 规则合并在 AIContract.swift，C# 检查集中 Program.cs；不增加计划中的多余类型文件。

Final build: 两平台由主助手重新构建通过；Mac pkg 全部5文件与 App 逐字节一致；包与架构验证通过；生成 Dist/SHA256SUMS.txt 与 release-manifest.json。

Sync: 83 个源码/资源/分发文件已核对并同步回原项目。旧版退出，新版已启动；首次窗口确认组件自动复用成功，辅助功能与屏幕录制需本人允许。原备份位于原项目 Backups/。

Repair 2026-10-11: Windows 损坏设置与模型缓存的启动异常已复现、修复；回归测试与自包含安装包构建通过。CLI 兼容性检查补齐六个必需参数。Windows 实机与签名仍待验证。
Mac: 本人已明确授权恢复原本地签名。钥匙串解锁成功；原证书签名、arm64/x86_64 构建及严格校验通过；修复版与安装包已同步。热键 ID 注册、路由和公开英文 OCR 检查通过；安装包全部文件与修复版一致。自动 UI 工具无法可靠触发全局热键，实际 Option+D 截图与翻译等待本人确认，尚未声称恢复使用。密码未输出、未写入新文件。

Translation tags repair: 本人确认原签名修复后截图翻译可用。CodeBuddy 本机程序包含 user_query 内部标记。两平台最终成功正文清理这两个标记；原文含同名标签时保留，普通 HTML/代码不修改；提示词禁止输出新增包装标签。Swift/C# 先复现泄漏，再验证清理与原文保留；Windows 全部检查和自包含发布通过，Mac 原证书 Universal 构建、测试包生成通过。源码无 Git / origin，不能提交推送。
Final tag verification: 两个真实 HY3 结果通过：普通英文不带内部标签；原文同名代码标签保留。Mac 资料以 JSON 字符串发送，避免原文与 CLI 包装混淆。两平台最终构建通过，Mac 包全部文件与 App 一致。Windows 真机检查仍待完成。

Meaning repair: 本人批准孤立词、专名与多义提示。两平台统一缩写翻译规则：保留缩写并补中文含义；多义注明领域和上下文不足；未知缩写不编造。译文与原文完全相同会附处理说明；中文提示无需另译。Swift/C# 回归与构建通过；八个真实 HY3 输入全部通过：Windows、API、MCP、未知缩写、两句上下文、中文和原文代码标签。Mac 包文件一致，Windows 实机仍待验证。
