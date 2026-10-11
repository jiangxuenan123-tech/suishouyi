// 探针 5：端到端验证
// 模拟真实使用场景：一张英文字片 → 识别文字 → 翻译成中文
// 这条链路和 App 里"框选截图翻译"走的是完全相同的代码路径

import Foundation
import Vision
import CoreGraphics
import CoreText
import Translation

// ============ 第一步：造一张"英文截图" ============
let width = 700, height = 220
guard let ctx = CGContext(
    data: nil, width: width, height: height,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("创建画布失败") }

ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

// 一段带点技术味的英文，模拟你平时要看的内容
let lines = [
    "Please restart the application after",
    "installing the update. If the problem",
    "persists, contact system support."
]
let font = CTFontCreateWithName("Helvetica" as CFString, 26, nil)

for (i, line) in lines.enumerated() {
    let attr = NSAttributedString(string: line, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    ])
    ctx.textPosition = CGPoint(x: 30, y: Double(height - 50 - i * 40))
    CTLineDraw(CTLineCreateWithAttributedString(attr), ctx)
}

guard let testImage = ctx.makeImage() else { fatalError("生成图片失败") }
print("① 已生成一张英文图片（\(width)×\(height)）\n")

// ============ 第二步：OCR 识别 ============
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.recognitionLanguages = ["en-US"]
request.usesLanguageCorrection = true

try VNImageRequestHandler(cgImage: testImage, options: [:]).perform([request])

let recognized = (request.results ?? [])
    .compactMap { $0.topCandidates(1).first?.string }
    .joined(separator: " ")

print("② 识别出的英文：")
print("   \(recognized)\n")

guard !recognized.isEmpty else {
    print("❌ 没识别出文字")
    exit(1)
}

// ============ 第三步：翻译 ============
let session = TranslationSession(
    installedSource: Locale.Language(identifier: "en"),
    target: Locale.Language(identifier: "zh-Hans")
)

do {
    let response = try await session.translate(recognized)
    print("③ 翻译结果：")
    print("   \(response.targetText)\n")
    print("✅ 端到端链路全部打通：图片 → 识别 → 翻译")
} catch {
    print("❌ 翻译失败：\(error)")
}
