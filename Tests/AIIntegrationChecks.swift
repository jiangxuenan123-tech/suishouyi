import Foundation

@main struct AIIntegrationChecks {
    static func main() async throws {
        let samples: [(TaskMode, String)] = [(.translation, "Correlation does not imply causation."), (.explanation, "相对论"), (.explanation, "相关性并不意味着因果关系。"), (.explanation, "热天冰淇淋卖得多，中暑的人也多。两者一起增加，可能是因为共同受到高温影响，不能据此判断吃冰淇淋导致中暑。")]
        for (mode, text) in samples {
            let result = try await Translator.shared.process(text, mode: mode, modelId: "hy3")
            guard !result.body.isEmpty, result.source == "ai", result.originalText == text else { fatalError("not AI result") }
            if mode == .explanation && result.body.count > 100 { fatalError("over 100 characters") }
            print("PASS \(mode.rawValue) kind=\(result.kind?.rawValue ?? "translation") characters=\(result.body.count) model=\(result.actualModelId ?? result.requestedModelId ?? "unknown"): \(result.body)")
        }
    }
}
