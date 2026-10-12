# 随手译 1.2.0

选中文字或框选屏幕，翻译成简体中文，或获得 100 字以内的名词、句子和短段落解释。

## 使用

| 操作 | Mac | Windows |
| --- | --- | --- |
| 翻译 | Option+D | Ctrl+Shift+F8 |
| 解释 | Option+E | Ctrl+Shift+F9 |

先在其他应用选中文字，再按快捷键；没有选中文字时进入框选截图。Esc 取消框选。

结果窗口可以切换翻译／解释、展开原文和复制结果。两种模式沿用同一份原文，默认同时生成翻译与解释，先完成的先显示。切换时直接读取当前窗口的结果，未完成时显示进度，不重复请求。可以在设置中关闭“同时生成”；关闭后仅生成当前选择的内容。同时生成会增加模型用量。处理中可以取消；关闭窗口会取消未完成的请求。

菜单栏／托盘和结果窗口可以切换 AI 模型，首次默认 HY3；设置提供快捷键和“简洁精致”“深色科技”两种外观。选择自动保存。切换模型用于下一次请求，当前结果标注它实际使用的模型。

## 安装

GitHub 公开仓库：[suishouyi](https://github.com/jiangxuenan123-tech/suishouyi)。现有 Mac 与 Windows 安装包在 [Releases](https://github.com/jiangxuenan123-tech/suishouyi/releases) 下载；源码中的 `Dist/` 保留校验清单和界面预览。本机签名私钥、含旧密码的备份和重复构建目录不上传。

Mac 需要 macOS 26 或更新版本；支持 Apple Silicon 与 Intel。安装包在 `Dist/`。Windows 候选版面向 Windows 10 2004 或更新版本的 x64 电脑，安装包也在 `Dist/`。

应用自动准备 CodeBuddy。Windows 包含 .NET 运行依赖与中英文 OCR。每位使用者完成自己的官方 CodeBuddy 登录；Mac 屏幕录制、辅助功能，以及系统要求的安装确认由本人完成。无需输入命令或安装开发工具。

截图识字在本机完成，识别后的文字会发送给所选 AI 模型。使用本人的 CodeBuddy 账号与额度，安装包不含开发者账号或密钥。

登录失效时点“重新登录”，模型不可用时点“切换模型”；完成后点“重试”，沿用原文。Mac 的 AI 网络故障可以使用已安装的苹果本地翻译，窗口会标注“本地翻译”。解释需要 AI。

## 当前交付状态

已完成源码、Mac 双架构构建和 Windows 自包含安装包构建；Mac 本机核心、剪贴板、双主题渲染、热键事件分发、OCR 图片和四个 HY3 公开样例检查通过。

当前为测试候选版。Mac 未具备 Developer ID 签名和 Apple 公证；Windows 未签名、尚未经过 Windows 真机安装及操作验证。干净 Mac、Intel Mac、多屏混合缩放等检查仍待完成。不要将这些包标为已经验证的正式发行版。

详细使用与验证状态见 `Distribution/RELEASE-CHECKLIST.md`、`Windows/USER-GUIDE.md`。

## 构建检查

Mac：`bash build.sh`；检查：`bash Tests/run-checks.sh`。剪贴板和 AppKit 检查需要桌面会话权限。`--live` 额外调用本人账号的四个公开 HY3 样例。

Mac 包：`bash Distribution/package-mac.sh`。Windows：设置 `SUISHOUYI_DOTNET` 为 .NET 10 SDK 的 dotnet 路径后运行 `bash Distribution/build-windows.sh`。
