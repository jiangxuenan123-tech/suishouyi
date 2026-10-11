# 第三方组件

随手译首次使用 AI 功能时，会复用或从官方源下载腾讯 CodeBuddy Code 原生 CLI。CLI 未随安装包分发；无需 Node.js。原生安装当前由官方标为 Beta。

- [官方安装说明](https://www.codebuddy.cn/docs/cli/installation)
- [官方安装脚本](https://www.codebuddy.cn/cli/install.sh)
- [官方登录说明](https://www.codebuddy.cn/docs/cli/quickstart)
- [官方账号登录命令](https://www.codebuddy.cn/docs/cli/slash-commands)
- [官方发布目录](https://acc-1258344699.cos.accelerate.myqcloud.com/@tencent-ai/codebuddy-code/releases)

CLI 的使用、账号和额度遵循腾讯 CodeBuddy 官方条款。随手译不授予、转售或改变第三方组件许可。用户使用自己的账号完成官方登录；应用不包含私人密钥、token、开发者账号配置或登录凭据。

下载前解析官方版本；执行前核对官方同版本 checksums.txt 的 SHA256。该校验可检测文件损坏或不匹配，不代表第三方压缩包获得 Apple 签名、公证或独立来源认证。

应用使用系统 AppKit、Vision、NaturalLanguage、ApplicationServices、CryptoKit 和 Translation 框架，由 macOS 提供。没有把这些系统框架复制到分发包。
