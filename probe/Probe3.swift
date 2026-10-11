// 探针 3：验证 macOS 26 新增的 TranslationSession 直接构造法能否跑通真实翻译
import Foundation
import Translation

print("开始……")

// 构造会话：英语 -> 简体中文
let session = TranslationSession(
    installedSource: Locale.Language(identifier: "en"),
    target: Locale.Language(identifier: "zh-Hans")
)

print("canRequestDownloads（能否请求下载语言包）：\(session.canRequestDownloads)")
print("isReady（是否就绪）：\(session.isReady)")

do {
    let response = try await session.translate("The quick brown fox jumps over the lazy dog.")
    print("原文：\(response.sourceText)")
    print("译文：\(response.targetText)")
    print("✅ 命令行翻译成功")
} catch {
    print("❌ 翻译失败：\(error)")
    print("错误详情：\(String(describing: error))")
}
