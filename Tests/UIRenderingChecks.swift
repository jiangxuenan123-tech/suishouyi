import AppKit

@main struct UIRenderingChecks {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let panel = ResultPanel()
        let originalTheme = AppSettings.shared.theme
        defer { AppSettings.shared.theme = originalTheme; panel.hidePanel() }
        let result = AIResult(body: "两个现象一起出现，不一定说明一个导致了另一个。比如，冰淇淋销量和中暑人数都随高温增加，但吃冰淇淋并不是中暑的原因。", originalText: "Correlation does not imply causation.", source: "ai", requestedModelId: "hy3", actualModelId: "hy3", mode: .explanation, kind: .sentence)
        let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for theme in [AppTheme.refinedLight, .techDark] {
            AppSettings.shared.theme = theme
            panel.updateSettings(); panel.showResult(result)
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            guard let view = panel.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { fatalError("no UI bitmap") }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(theme.rawValue + ".png"))
        }
        panel.showResult(AIResult(body: String(repeating: "这是一段用于检查长译文滚动阅读的内容。\n", count: 100), originalText: result.originalText, source: "ai", requestedModelId: "hy3", actualModelId: nil, mode: .translation, kind: nil))
        guard panel.frame.height < 700 else { fatalError("long content exceeds screen") }
        let scrollers = panel.contentView!.subviews.compactMap { $0 as? NSScrollView }
        guard let body = scrollers.first?.documentView as? NSTextView, body.string.count > 1000, scrollers.first!.hasVerticalScroller else { fatalError("long text was truncated") }
        print("PASS: both native themes rendered; long text preserved with scrolling")
    }
}
