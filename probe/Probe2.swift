// 探针 2：改用顶层 await，避免阻塞主线程造成的死锁
import Foundation
import Translation

print("开始探测…")

let availability = LanguageAvailability()
let supported = await availability.supportedLanguages
print("框架支持的语言数量：\(supported.count)")

let en = Locale.Language(identifier: "en")
let zh = Locale.Language(identifier: "zh-Hans")
let status = await availability.status(from: en, to: zh)
print("英语 -> 简体中文 状态：\(status)")

print("探测完成")
