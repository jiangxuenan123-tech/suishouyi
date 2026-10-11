import AppKit

@main struct WorkflowChecks {
    static func main() {
        let board = NSPasteboard(name: .init("SuishouyiChecks-" + UUID().uuidString))
        let item = NSPasteboardItem()
        item.setString("原来的文字", forType: .string)
        item.setData(Data([1,2,3]), forType: .png)
        board.writeObjects([item])
        let snapshot = ClipboardSnapshot(board)
        board.clearContents(); board.setString("选中的内容", forType: .string)
        snapshot.restore(board, ifUnchangedSince: board.changeCount)
        guard board.string(forType: .string) == "原来的文字", board.data(forType: .png) == Data([1,2,3]) else { fatalError("clipboard formats lost") }
        let count = board.changeCount
        board.clearContents(); board.setString("用户的新复制", forType: .string)
        snapshot.restore(board, ifUnchangedSince: count)
        guard board.string(forType: .string) == "用户的新复制" else { fatalError("user clipboard overwritten") }
        let name = "SuishouyiSettings-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name); board.releaseGlobally() }
        let settings = AppSettings(defaults: defaults)
        guard settings.modelId == "hy3", settings.theme == .refinedLight else { fatalError("first run defaults") }
        settings.theme = .techDark; settings.modelId = "example-other-model"
        let restored = AppSettings(defaults: defaults)
        guard restored.theme == .techDark, restored.modelId == "example-other-model" else { fatalError("preferences not restored") }
        print("PASS: full clipboard restore, concurrent copy preserved, first run defaults and saved theme/model")
    }
}
