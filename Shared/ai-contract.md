# AI 契约

translation: 简体中文；保留中文、段落、列表、数字、否定、语气；不补充原文。
explanation: 简体中文；名词/句子/短段落；易懂；不猜缩写；解释正文 <=100 Unicode 字素。
解释 JSON：{"status":"ok|uncertain|needs_selection","kind":"term|sentence|paragraph","subject":"对象","body":"解释"}。
needs_selection: 输入混杂或缺失到无法理解；连贯段落多个概念照常解释。
超长：原模型压缩一次；仍超长提示重试，不截断。
模型：首选 hy3；用户可切换；每请求固定 ID；正文仅最终成功 result。
进程：--print --output-format json --tools '' --strict-mcp-config --mcp-config '{"mcpServers":{}}' --no-session-persistence；stdin 输入；独立目录；同时读 stdout/stderr；45s 超时；取消杀子进程。
UI：当前窗口缓存两模式；切换不重新读屏幕；模型/主题切换不自动重发；来源显示实际模型或请求模型，不猜。
热键：Mac Option+D/E；Windows Ctrl+Shift+F8/F9；可修改；冲突保留菜单操作。
主题：refinedLight（简洁精致）/techDark（深色科技）；存储本人设置；窗口关闭取消。
安装：原生 CodeBuddy 官方来源；本人登录授权；不分发个人凭据。
