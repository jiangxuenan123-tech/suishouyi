import AppKit
import Carbon.HIToolbox

@main struct InputChecks {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        var calls = [0, 0]
        guard let first = HotKeyManager(keyCode: 79, modifiers: UInt32(controlKey | optionKey | shiftKey), id: 101, callback: { calls[0] += 1 }),
              let second = HotKeyManager(keyCode: 80, modifiers: UInt32(controlKey | optionKey | shiftKey), id: 102, callback: { calls[1] += 1 }) else { fatalError("check shortcuts unavailable") }
        for id in [UInt32(101), 102] {
            var event: EventRef?
            precondition(CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed), GetCurrentEventTime(), EventAttributes(kEventAttributeUserEvent), &event) == noErr)
            var key = EventHotKeyID(signature: 0x53535949, id: id)
            precondition(SetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), MemoryLayout<EventHotKeyID>.size, &key) == noErr)
            precondition(SendEventToEventTarget(event, GetApplicationEventTarget()) == noErr)
            ReleaseEvent(event)
        }
        withExtendedLifetime([first, second]) { precondition(calls == [1, 1], "hotkey IDs dispatched to wrong action") }
        let image = NSImage(size: NSSize(width: 900, height: 120))
        image.lockFocus()
        NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 900, height: 120).fill()
        ("Correlation does not imply causation." as NSString).draw(at: NSPoint(x: 24, y: 45), withAttributes: [.font: NSFont.systemFont(ofSize: 32), .foregroundColor: NSColor.black])
        image.unlockFocus()
        let text = try await ScreenOCR.recognizeText(in: image.cgImage(forProposedRect: nil, context: nil, hints: nil)!)
        precondition(text.contains("Correlation") && text.contains("causation"), "OCR did not retain the source")
        print("PASS: two native hotkey IDs route separately; screenshot OCR retains English source")
    }
}
