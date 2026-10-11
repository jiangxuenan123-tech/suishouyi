// 探针 1：苹果自带翻译框架能否在命令行环境下调用
// 目的：确认 Translation.framework 可用，并查看中英语言包状态

import Foundation
import Translation

let semaphore = DispatchSemaphore(value: 0)

Task {
    let availability = LanguageAvailability()

    // 1. 查询框架支持的全部语言
    let supported = await availability.supportedLanguages
    print("【支持的语言数量】\(supported.count)")

    // 2. 查询英语 -> 简体中文的可用状态
    let en = Locale.Language(identifier: "en")
    let zh = Locale.Language(identifier: "zh-Hans")
    let status = await availability.status(from: en, to: zh)

    let readable: String
    switch status {
    case .installed:  readable = "已安装（可离线翻译）"
    case .supported:  readable = "支持，但需下载语言包"
    case .unsupported: readable = "不支持这一对语言"
    @unknown default: readable = "未知状态"
    }

    print("【英 -> 简体中文】\(readable)")

    semaphore.signal()
}

semaphore.wait()
print("探测结束")
