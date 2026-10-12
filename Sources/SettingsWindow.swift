import AppKit
import Carbon.HIToolbox

final class ShortcutRecorder: NSButton {
    var recorded: ((UInt32, UInt32, String) -> Bool)?
    private var recording = false
    override var acceptsFirstResponder: Bool { true }
    @objc func begin() { recording = true; title = "请按组合键，Esc 取消"; window?.makeFirstResponder(self) }
    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        if event.keyCode == 53 { recording = false; title = "点击重新设置"; return }
        var mods: UInt32 = 0
        let flags = event.modifierFlags
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        guard mods != 0 else { title = "请搭配 ⌥ / ⌘ / ⇧ / ⌃"; return }
        let label = (flags.contains(.control) ? "⌃" : "") + (flags.contains(.option) ? "⌥" : "") + (flags.contains(.shift) ? "⇧" : "") + (flags.contains(.command) ? "⌘" : "") + (event.charactersIgnoringModifiers?.uppercased() ?? "键")
        recording = false
        title = recorded?(UInt32(event.keyCode), mods, label) == true ? label : "组合键冲突，原快捷键仍有效"
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if recording { keyDown(with: event); return true }
        return super.performKeyEquivalent(with: event)
    }
}

@MainActor final class SettingsWindow: NSObject {
    private let settings = AppSettings.shared
    private var window: NSWindow?
    private let model = NSPopUpButton()
    private let theme = NSPopUpButton()
    private let parallel = NSButton(checkboxWithTitle: "同时生成翻译和解释（增加模型用量）", target: nil, action: nil)
    private let status = NSTextField(wrappingLabelWithString: "模型能否使用以当前账号权限和额度为准。")
    var onShortcut: ((TaskMode, UInt32, UInt32) -> Bool)?
    var onSetup: (() -> Void)?
    func show() {
        if window == nil { makeWindow() }
        update(); window?.center(); window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func update() {
        guard window != nil else { return }
        let palette = settings.theme
        window?.appearance = palette.appearance; window?.backgroundColor = palette.background
        model.removeAllItems()
        var ids = settings.models
        if !ids.contains(settings.modelId) { ids.insert(settings.modelId, at: 0) }
        model.addItems(withTitles: ids); model.selectItem(withTitle: settings.modelId)
        theme.selectItem(at: settings.theme == .refinedLight ? 0 : 1)
        parallel.state = settings.parallelGeneration ? .on : .off
    }
    @objc private func changeModel() { if let id = model.titleOfSelectedItem { settings.modelId = id } }
    @objc private func changeParallel() { settings.parallelGeneration = parallel.state == .on }
    @objc private func changeTheme() { settings.theme = theme.indexOfSelectedItem == 0 ? .refinedLight : .techDark }
    @objc func refreshModels() {
        status.stringValue = "正在读取 CodeBuddy 支持的模型…"
        Task {
            do {
                let data = try await CodeBuddyClient.run(executable: CodeBuddyClient.executable(), arguments: ["--help"], timeout: 10)
                let ids = AIContract.models(String(data: data, encoding: .utf8) ?? "")
                guard !ids.isEmpty else { throw AIError.malformedResponse }
                settings.models = ids
                status.stringValue = ids.contains(settings.modelId) ? "列表已更新。实际可用性以当前账号为准。" : "列表已更新；保存的模型不在当前列表中，请确认选择。"
                update()
            } catch { status.stringValue = "刷新失败，已保留原列表和选择。请检查组件后重试。" }
        }
    }
    @objc private func restoreModel() { settings.modelId = "hy3" }
    @objc private func setup() { onSetup?() }
    private func makeWindow() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 540), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        self.window = window; window.title = "随手译 · 设置"; window.isReleasedWhenClosed = false
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 28), stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -28), stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 28)])
        model.target = self; model.action = #selector(changeModel)
        theme.addItems(withTitles: ["简洁精致", "深色科技"]); theme.target = self; theme.action = #selector(changeTheme)
        for (label, control) in [("AI 模型", model), ("外观", theme)] {
            let row = NSStackView(views: [NSTextField(labelWithString: label), control]); row.spacing = 20; stack.addArrangedSubview(row)
            control.widthAnchor.constraint(equalToConstant: 280).isActive = true
        }
        parallel.target = self; parallel.action = #selector(changeParallel); stack.addArrangedSubview(parallel)
        let refresh = NSButton(title: "刷新模型列表", target: self, action: #selector(refreshModels))
        let restore = NSButton(title: "恢复 HY3", target: self, action: #selector(restoreModel))
        stack.addArrangedSubview(NSStackView(views: [refresh, restore])); stack.addArrangedSubview(status)
        for mode in [TaskMode.translation, .explanation] {
            let label = NSTextField(labelWithString: mode == .translation ? "翻译快捷键" : "解释快捷键")
            let recorder = ShortcutRecorder(title: "点击设置（默认 ⌥" + (mode == .translation ? "D" : "E") + "）", target: nil, action: nil)
            recorder.target = recorder; recorder.action = #selector(ShortcutRecorder.begin)
            recorder.recorded = { [weak self] key, mods, _ in self?.onShortcut?(mode, key, mods) ?? false }
            stack.addArrangedSubview(NSStackView(views: [label, recorder]))
        }
        stack.addArrangedSubview(NSButton(title: "登录、组件与权限设置", target: self, action: #selector(setup)))
        stack.addArrangedSubview(NSTextField(wrappingLabelWithString: "截图识字在本机完成，选中文字会发送给当前 AI 模型。模型切换用于下次请求；同时生成开关用于下次选取，当前结果不会自动重发。"))
    }
}
