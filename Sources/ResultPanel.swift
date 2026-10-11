import AppKit

final class ResultPanel: NSPanel {
    private let settings = AppSettings.shared
    private let titleLabel = NSTextField(labelWithString: "随手译")
    private let heading = NSTextField(labelWithString: "")
    private let sourceLabel = NSTextField(labelWithString: "")
    private let tabs = NSSegmentedControl(labels: ["翻译", "解释"], trackingMode: .selectOne, target: nil, action: nil)
    private let model = NSPopUpButton()
    private let theme = NSPopUpButton()
    private let bodyText = NSTextView()
    private let originalText = NSTextView()
    private let bodyScroll = NSScrollView()
    private let originalScroll = NSScrollView()
    private let originalToggle = NSButton(title: "▸ 原文", target: nil, action: nil)
    private let copyButton = NSButton(title: "复制译文", target: nil, action: nil)
    private let actionButton = NSButton(title: "重试", target: nil, action: nil)
    private let closeButton = NSButton(title: "×", target: nil, action: nil)
    private let separator = NSBox()
    private var outsideMonitor: Any?
    private var expanded = false
    private var resultText = ""
    private var mode: TaskMode = .translation
    private var isLoading = false
    var onMode: ((TaskMode) -> Void)?
    var onClose: (() -> Void)?
    var onAction: (() -> Void)?
    var onCancel: (() -> Void)?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 500, height: 300), styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel], backing: .buffered, defer: false)
        titleVisibility = .hidden; titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] { standardWindowButton(button)?.isHidden = true }
        isFloatingPanel = true; level = .floating; hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true; isReleasedWhenClosed = false; isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        contentView = NSView(); contentView?.wantsLayer = true
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        heading.font = .systemFont(ofSize: 12, weight: .medium)
        sourceLabel.font = .systemFont(ofSize: 11)
        for (text, scroll) in [(bodyText, bodyScroll), (originalText, originalScroll)] {
            text.isEditable = false; text.isSelectable = true; text.drawsBackground = false
            text.isRichText = false; text.font = .systemFont(ofSize: 17)
            text.textContainerInset = NSSize(width: 2, height: 6)
            text.isVerticallyResizable = true; text.isHorizontallyResizable = false
            text.autoresizingMask = [.width]; text.textContainer?.widthTracksTextView = true
            scroll.documentView = text; scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        }
        originalText.font = .systemFont(ofSize: 13)
        for control in [copyButton, actionButton, closeButton, originalToggle, model, theme] { control.target = self }
        copyButton.action = #selector(copyResult); actionButton.action = #selector(actionClicked)
        closeButton.action = #selector(closeClicked); originalToggle.action = #selector(toggleOriginal)
        tabs.target = self; tabs.action = #selector(modeChanged)
        model.action = #selector(modelChanged); theme.action = #selector(themeChanged)
        for control in [copyButton, actionButton, closeButton, originalToggle] { control.bezelStyle = .rounded }
        copyButton.keyEquivalent = ""; copyButton.setAccessibilityLabel("复制结果")
        tabs.setAccessibilityLabel("翻译或解释"); model.setAccessibilityLabel("AI 模型"); theme.setAccessibilityLabel("界面外观")
        separator.boxType = .separator
        for view in [titleLabel, heading, sourceLabel, tabs, model, bodyScroll, originalToggle, originalScroll, copyButton, actionButton, closeButton, theme, separator] { contentView?.addSubview(view) }
        updateSettings()
    }
    func updateSettings() {
        let palette = settings.theme
        appearance = palette.appearance
        contentView?.layer?.backgroundColor = palette.background.cgColor
        contentView?.layer?.cornerRadius = 16
        for label in [titleLabel, heading, sourceLabel] { label.textColor = label === titleLabel ? palette.text : palette.secondary }
        bodyText.textColor = palette.text; originalText.textColor = palette.secondary
        tabs.selectedSegmentBezelColor = palette.accent.withAlphaComponent(0.2)
        for button in [copyButton, actionButton, originalToggle, closeButton] {
            button.isBordered = false; button.wantsLayer = true
            button.layer?.cornerRadius = 9
            let foreground = button === copyButton ? NSColor.white : palette.secondary
            button.attributedTitle = NSAttributedString(string: button.title, attributes: [.foregroundColor: foreground, .font: NSFont.systemFont(ofSize: 14, weight: button === copyButton ? .medium : .regular)])
            button.layer?.backgroundColor = button === copyButton ? palette.accent.cgColor : (button === actionButton ? palette.inset.cgColor : NSColor.clear.cgColor)
        }
        originalScroll.drawsBackground = true; originalScroll.backgroundColor = palette.inset
        originalScroll.wantsLayer = true; originalScroll.layer?.cornerRadius = 9
        model.removeAllItems()
        var models = settings.models
        if !models.contains(settings.modelId) { models.insert(settings.modelId, at: 0) }
        model.addItems(withTitles: models); model.selectItem(withTitle: settings.modelId)
        theme.removeAllItems(); theme.addItems(withTitles: ["简洁精致", "深色科技"])
        theme.selectItem(at: settings.theme == .refinedLight ? 0 : 1)
    }
    func showLoading(original: String, mode: TaskMode, message: String? = nil, modelId: String? = nil) {
        self.mode = mode; isLoading = true; resultText = ""
        tabs.selectedSegment = mode == .translation ? 0 : 1
        heading.stringValue = message ?? (mode == .translation ? "翻译中…" : "解释中…")
        bodyText.string = "正在处理，你可以随时取消。"
        originalText.string = original; sourceLabel.stringValue = "当前请求：" + (modelId ?? settings.modelId)
        copyButton.isEnabled = false; actionButton.title = "取消处理"; actionButton.isHidden = false
        updateSettings(); layoutContent(); present()
    }
    func showResult(_ result: AIResult) {
        mode = result.mode; isLoading = false; resultText = result.body
        tabs.selectedSegment = mode == .translation ? 0 : 1
        heading.stringValue = mode == .translation ? "中文译文" : [ExplanationKind.term: "名词解释", .sentence: "句子解释", .paragraph: "段落解释"][result.kind ?? .term]!
        bodyText.string = result.body; originalText.string = result.originalText
        sourceLabel.stringValue = result.source == "local" ? "本地翻译 · AI 暂时不可用" : "本次模型：" + (result.actualModelId ?? result.requestedModelId ?? "AI")
        copyButton.title = mode == .translation ? "复制译文" : "复制解释"
        copyButton.isEnabled = true; actionButton.isHidden = true
        updateSettings(); layoutContent(); present()
    }
    func showError(_ message: String, original: String = "", actionTitle: String = "重试") {
        isLoading = false; resultText = ""; heading.stringValue = "暂时没有完成"
        bodyText.string = message; originalText.string = original
        copyButton.isEnabled = false; actionButton.title = actionTitle; actionButton.isHidden = false
        sourceLabel.stringValue = "原文会保留在当前窗口"
        updateSettings(); layoutContent(); present()
    }
    func showBusy() { heading.stringValue = "任务仍在处理中，可以取消后再操作。"; present() }
    func showSlow() { if isLoading { heading.stringValue = "AI 响应稍慢，仍在等待；可以取消。" } }
    func setMode(_ mode: TaskMode) { tabs.selectedSegment = mode == .translation ? 0 : 1 }
    func hidePanel() { stopMonitor(); orderOut(nil) }
    private func layoutContent() {
        let width: CGFloat = 452
        let font = NSFont.systemFont(ofSize: mode == .translation && bodyText.string.count < 45 ? 20 : 17, weight: .regular)
        bodyText.font = font
        let textHeight = (bodyText.string as NSString).boundingRect(with: NSSize(width: width - 18, height: 10000), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font]).height
        let bodyHeight = min(310, max(55, ceil(textHeight) + 20))
        let originalHeight: CGFloat = expanded ? 100 : 0
        let height = 272 + bodyHeight + originalHeight
        setContentSize(NSSize(width: 500, height: height))
        titleLabel.frame = NSRect(x: 24, y: height - 50, width: 350, height: 26)
        closeButton.frame = NSRect(x: 443, y: height - 50, width: 32, height: 26)
        tabs.frame = NSRect(x: 24, y: height - 98, width: 280, height: 32)
        model.frame = NSRect(x: 343, y: height - 98, width: 132, height: 32)
        heading.frame = NSRect(x: 24, y: height - 130, width: width, height: 20)
        bodyScroll.frame = NSRect(x: 24, y: height - 142 - bodyHeight, width: width, height: bodyHeight)
        bodyText.frame = NSRect(x: 0, y: 0, width: width, height: bodyHeight)
        originalToggle.frame = NSRect(x: 20, y: 95 + originalHeight, width: 120, height: 26)
        separator.frame = NSRect(x: 24, y: 126 + originalHeight, width: width, height: 1)
        originalScroll.isHidden = !expanded
        originalScroll.frame = NSRect(x: 24, y: 94, width: width, height: originalHeight)
        originalText.frame = NSRect(x: 0, y: 0, width: width, height: originalHeight)
        sourceLabel.frame = NSRect(x: 24, y: 69, width: width, height: 18)
        theme.frame = NSRect(x: 24, y: 24, width: 150, height: 30)
        actionButton.frame = NSRect(x: 210, y: 24, width: 112, height: 32)
        copyButton.frame = NSRect(x: 347, y: 24, width: 128, height: 32)
    }
    private func present() {
        if !isVisible {
            let mouse = NSEvent.mouseLocation
            let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
            if let visible = screen?.visibleFrame {
                setFrameOrigin(NSPoint(x: max(visible.minX, min(mouse.x + 14, visible.maxX - frame.width)), y: max(visible.minY, min(mouse.y - frame.height - 14, visible.maxY - frame.height))))
            }
        } else if let visible = screen?.visibleFrame {
            setFrameOrigin(NSPoint(x: max(visible.minX, min(frame.minX, visible.maxX - frame.width)), y: max(visible.minY, min(frame.minY, visible.maxY - frame.height))))
        }
        orderFrontRegardless()
        if outsideMonitor == nil {
            outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                guard let self, self.isVisible, !self.frame.contains(NSEvent.mouseLocation) else { return }
                DispatchQueue.main.async { self.closeClicked() }
            }
        }
    }
    private func stopMonitor() { if let outsideMonitor { NSEvent.removeMonitor(outsideMonitor) }; outsideMonitor = nil }
    @objc private func modeChanged() { onMode?(tabs.selectedSegment == 0 ? .translation : .explanation) }
    @objc private func modelChanged() { if let id = model.titleOfSelectedItem { settings.modelId = id } }
    @objc private func themeChanged() { settings.theme = theme.indexOfSelectedItem == 0 ? .refinedLight : .techDark }
    @objc private func toggleOriginal() { expanded.toggle(); originalToggle.title = expanded ? "▾ 原文" : "▸ 原文"; layoutContent(); present() }
    @objc private func copyResult() {
        guard !resultText.isEmpty else { return }
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(resultText, forType: .string)
        copyButton.title = "已复制 ✓"
        updateSettings()
    }
    @objc private func actionClicked() { if isLoading { onCancel?() } else { onAction?() } }
    @objc private func closeClicked() { onClose?(); hidePanel() }
    override func cancelOperation(_ sender: Any?) { closeClicked() }
    deinit { stopMonitor() }
}
