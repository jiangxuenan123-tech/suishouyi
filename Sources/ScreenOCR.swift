import AppKit
import Vision

enum InputError: Error, LocalizedError {
    case screenPermission, noText, unclearText, recognitionFailed
    var errorDescription: String? {
        switch self {
        case .screenPermission: return "屏幕授权尚未在当前版本生效。请允许随手译录屏，再完全退出并重新打开。若开关已经打开，请关闭后重新打开，再重启随手译。"
        case .noText: return "没有识别到文字，请框选包含文字的区域。"
        case .unclearText: return "文字太模糊，请放大原页面或缩小截图范围。"
        case .recognitionFailed: return "图片识别未完成，请重新框选。"
        }
    }
}
enum ScreenOCR {
    static func captureInteractiveSelection() async throws -> CGImage? {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else { throw InputError.screenPermission }
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("suishouyi_" + UUID().uuidString + ".png")
        defer { try? FileManager.default.removeItem(at: path) }
        do { _ = try await CodeBuddyClient.run(executable: "/usr/sbin/screencapture", arguments: ["-i", "-x", "-t", "png", path.path], timeout: 120) }
        catch is CancellationError { throw CancellationError() }
        catch { return nil } // Esc cancels the system selection UI.
        guard let image = NSImage(contentsOf: path) else { return nil }
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
    static func recognizeText(in image: CGImage) async throws -> String {
        try await Task.detached {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US", "zh-Hans", "ja-JP", "ko-KR"]
            request.usesLanguageCorrection = true
            do { try VNImageRequestHandler(cgImage: image, options: [:]).perform([request]) }
            catch { throw InputError.recognitionFailed }
            let observations = request.results ?? []
            let candidates = observations.compactMap { $0.topCandidates(1).first }
            guard !candidates.isEmpty else { throw InputError.noText }
            guard candidates.contains(where: { $0.confidence >= 0.3 }) else { throw InputError.unclearText }
            return candidates.map(\.string).joined(separator: "\n")
        }.value
    }
}
