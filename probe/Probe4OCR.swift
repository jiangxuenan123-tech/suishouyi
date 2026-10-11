// 探针 4：验证苹果 Vision 框架的 OCR 能力（把图片里的文字读出来）
import Foundation
import Vision
import CoreGraphics
import CoreText

// ---- 第一步：现场生成一张带英文文字的测试图片 ----
let width = 800, height = 200
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: width, height: height,
    bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("创建画布失败") }

ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

let line1 = "Hello world, this is an OCR test."
let line2 = "Machine learning models require training data."
let font = CTFontCreateWithName("Helvetica" as CFString, 30, nil)

for (i, line) in [line1, line2].enumerated() {
    let attr = NSAttributedString(string: line, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    ])
    let ctLine = CTLineCreateWithAttributedString(attr)
    ctx.textPosition = CGPoint(x: 30, y: Double(height - 60 - i * 55))
    CTLineDraw(ctLine, ctx)
}

guard let testImage = ctx.makeImage() else { fatalError("生成图片失败") }
print("✅ 测试图片已生成：\(width)x\(height)")

// ---- 第二步：用 Vision 做文字识别 ----
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate            // accurate = 精确模式，慢但准
request.recognitionLanguages = ["en-US", "zh-Hans"]  // 支持的语言：英文 + 简体中文
request.usesLanguageCorrection = true

let handler = VNImageRequestHandler(cgImage: testImage, options: [:])
try handler.perform([request])

guard let observations = request.results else {
    print("❌ 没有识别结果"); exit(1)
}

print("\n识别到 \(observations.count) 行文字：")
for (i, obs) in observations.enumerated() {
    if let candidate = obs.topCandidates(1).first {
        let pct = String(format: "%.1f%%", candidate.confidence * 100)
        print("  \(i + 1). [\(pct)] \(candidate.string)")
    }
}
print("\n✅ Vision OCR 可用")
