import AppKit
import ApplicationServices

struct ClipboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]
    init(_ board: NSPasteboard) {
        items = (board.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in item.data(forType: type).map { (type, $0) } })
        }
    }
    func restore(_ board: NSPasteboard, ifUnchangedSince stamp: Int) {
        guard board.changeCount == stamp else { return }
        let restored = items.map { formats -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in formats { item.setData(data, forType: type) }
            return item
        }
        board.clearContents()
        board.writeObjects(restored)
    }
}

enum SelectionReader {
    @MainActor static func readSelectedText(from sourceApp: NSRunningApplication?) async -> String? {
        guard AXIsProcessTrusted() else { return nil }
        if let sourceApp, NSWorkspace.shared.frontmostApplication?.processIdentifier != sourceApp.processIdentifier {
            sourceApp.activate(options: [])
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        let sourcePid = sourceApp?.processIdentifier ?? NSWorkspace.shared.frontmostApplication?.processIdentifier
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == sourcePid else { return nil }
        if let text = readViaAccessibility(), !text.trimmed.isEmpty { return text }
        let board = NSPasteboard.general
        let snapshot = ClipboardSnapshot(board)
        let before = board.changeCount
        let source = CGEventSource(stateID: .combinedSessionState)
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: down)
            event?.flags = .maskCommand; event?.post(tap: .cghidEventTap)
        }
        let deadline = Date().addingTimeInterval(0.5)
        while board.changeCount == before && Date() < deadline && !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 20_000_000)
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == sourcePid else { return nil }
        }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == sourcePid else { return nil }
        guard board.changeCount != before else { return nil }
        let stamp = board.changeCount
        let text = board.string(forType: .string)
        snapshot.restore(board, ifUnchangedSince: stamp)
        return text?.trimmed.isEmpty == false ? text : nil
    }
    private static func readViaAccessibility() -> String? {
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &focused) == .success, let focused else { return nil }
        var selected: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused as! AXUIElement, kAXSelectedTextAttribute as CFString, &selected) == .success else { return nil }
        return selected as? String
    }
}
extension String { var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) } }
