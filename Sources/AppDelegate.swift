import AppKit
import ApplicationServices

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotKeys: [String: HotKeyManager] = [:]
    private let panel = ResultPanel()
    private let settingsWindow = SettingsWindow()
    private let setup = SetupCoordinator()
    private let settings = AppSettings.shared
    private var activeTask: Task<Void, Never>?
    private var currentMode: TaskMode = .translation
    private var original = ""
    private var results: [String: AIResult] = [:]
    private var sourceApp: NSRunningApplication?
    private var activationObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "译"
        statusItem.button?.toolTip = "随手译 · 翻译与解释"
        sourceApp = NSWorkspace.shared.frontmostApplication
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            Task { @MainActor [weak self] in self?.sourceApp = app }
        }
        panel.onMode = { [weak self] mode in self?.switchMode(mode) }
        panel.onClose = { [weak self] in self?.activeTask?.cancel() }
        panel.onCancel = { [weak self] in self?.activeTask?.cancel(); self?.panel.hidePanel() }
        settingsWindow.onSetup = { [weak self] in self?.setup.show() }
        settingsWindow.onShortcut = { [weak self] mode, key, modifiers in self?.changeShortcut(mode, key: key, modifiers: modifiers) ?? false }
        settings.changed = { [weak self] in self?.panel.updateSettings(); self?.settingsWindow.update(); self?.updateMenu() }
        for mode in [TaskMode.translation, .explanation] {
            let shortcut = settings.shortcut(mode)
            if !changeShortcut(mode, key: shortcut.key, modifiers: shortcut.modifiers) {
                panel.showError("快捷键被其他软件占用。菜单入口仍可使用，请在设置中更换快捷键。", actionTitle: "设置快捷键")
                panel.onAction = { [weak self] in self?.settingsWindow.show() }
            }
        }
        updateMenu()
        settingsWindow.refreshModels()
        if !UserDefaults.standard.bool(forKey: "setupShownV110") {
            UserDefaults.standard.set(true, forKey: "setupShownV110")
            setup.show()
        }
    }
    private func changeShortcut(_ mode: TaskMode, key: UInt32, modifiers: UInt32) -> Bool {
        let old = settings.shortcut(mode)
        if hotKeys[mode.rawValue] != nil, old.key == key, old.modifiers == modifiers { return true }
        guard let registered = HotKeyManager(keyCode: key, modifiers: modifiers, id: mode == .translation ? 1 : 2, callback: { [weak self] in self?.start(mode) }) else { return false }
        hotKeys[mode.rawValue] = registered
        settings.saveShortcut(mode, key: key, modifiers: modifiers)
        return true
    }
    private func updateMenu() {
        let menu = NSMenu()
        func add(_ title: String, _ action: Selector) { let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; menu.addItem(item) }
        add("翻译选中文字或框选截图", #selector(translateAction))
        add("解释选中文字或框选截图", #selector(explainAction))
        menu.addItem(.separator())
        let modelEntry = NSMenuItem(title: "AI 模型（当前：\(settings.modelId)）", action: nil, keyEquivalent: "")
        let models = NSMenu()
        var ids = settings.models
        if !ids.contains(settings.modelId) { ids.insert(settings.modelId, at: 0) }
        for id in ids {
            let item = NSMenuItem(title: id, action: #selector(selectModel(_:)), keyEquivalent: "")
            item.representedObject = id; item.target = self; item.state = id == settings.modelId ? .on : .off; models.addItem(item)
        }
        models.addItem(.separator())
        let refresh = NSMenuItem(title: "刷新模型列表", action: #selector(refreshModels), keyEquivalent: ""); refresh.target = self; models.addItem(refresh)
        let restore = NSMenuItem(title: "恢复 HY3", action: #selector(restoreModel), keyEquivalent: ""); restore.target = self; models.addItem(restore)
        modelEntry.submenu = models; menu.addItem(modelEntry)
        add("设置 · 外观与快捷键", #selector(openSettings))
        add("使用准备 · 登录与授权", #selector(openSetup))
        menu.addItem(.separator())
        add("退出随手译", #selector(quit))
        statusItem.menu = menu
    }
    @objc private func translateAction() { start(.translation) }
    @objc private func explainAction() { start(.explanation) }
    @objc private func openSettings() { settingsWindow.show() }
    @objc private func openSetup() { setup.show() }
    @objc private func refreshModels() { settingsWindow.refreshModels() }
    @objc private func restoreModel() { settings.modelId = "hy3" }
    @objc private func selectModel(_ sender: NSMenuItem) { if let id = sender.representedObject as? String { settings.modelId = id } }
    @objc private func quit() { activeTask?.cancel(); NSApp.terminate(nil) }
    private func switchMode(_ mode: TaskMode) {
        guard activeTask == nil else { panel.setMode(currentMode); panel.showBusy(); return }
        currentMode = mode
        if let result = results[mode.rawValue] { panel.showResult(result) }
        else { start(mode, reuse: !original.isEmpty) }
    }
    private func start(_ mode: TaskMode, reuse: Bool = false) {
        guard activeTask == nil else { panel.showBusy(); return }
        currentMode = mode
        let modelId = settings.modelId
        let app = sourceApp
        if !reuse { original = ""; results.removeAll() }
        activeTask = Task { [self] in
            defer { activeTask = nil }
            do {
                if !reuse {
                    panel.showLoading(original: "", mode: mode, message: "正在获取选中文字…", modelId: modelId)
                    if let selected = await SelectionReader.readSelectedText(from: app) {
                        original = selected
                    } else {
                        try Task.checkCancellation()
                        panel.hidePanel()
                        guard let image = try await ScreenOCR.captureInteractiveSelection() else { return }
                        panel.showLoading(original: "", mode: mode, message: "正在识别截图中的文字…", modelId: modelId)
                        original = try await ScreenOCR.recognizeText(in: image)
                    }
                }
                try Task.checkCancellation()
                guard !original.trimmed.isEmpty else { throw InputError.noText }
                let input = original
                panel.showLoading(original: input, mode: mode, modelId: modelId)
                let slow = Task { try? await Task.sleep(nanoseconds: 8_000_000_000); if !Task.isCancelled { panel.showSlow() } }
                defer { slow.cancel() }
                let result = try await Translator.shared.process(input, mode: mode, modelId: modelId)
                try Task.checkCancellation()
                results[mode.rawValue] = result
                panel.showResult(result)
            } catch is CancellationError { panel.hidePanel() }
            catch {
                if Task.isCancelled { panel.hidePanel(); return }
                var title = "重试"
                let retry: @MainActor () -> Void = { [weak self] in guard let self else { return }; self.start(mode, reuse: !self.original.isEmpty) }
                var action = retry
                func recover(_ message: String, operation: @escaping @MainActor () -> Void) -> @MainActor () -> Void {
                    { [weak self] in
                        operation()
                        self?.panel.onAction = retry
                        self?.panel.showError(message, original: self?.original ?? "", actionTitle: "重试")
                    }
                }
                if let error = error as? AIError {
                    switch error {
                    case .missingCLI: title = "自动准备组件"; action = recover("准备组件完成后，点击重试继续处理原文。") { [weak self] in self?.setup.show() }
                    case .loginRequired: title = "重新登录"; action = recover("完成登录后，点击重试继续处理原文。") { [weak self] in self?.setup.login() }
                    case .modelUnavailable: title = "切换模型"; action = recover("选择其他模型后，点击重试继续处理原文。") { [weak self] in self?.settingsWindow.show() }
                    default: break
                    }
                }
                if let input = error as? InputError {
                    switch input {
                    case .screenPermission: title = "前往权限设置"; action = { [weak self] in self?.setup.show() }
                    default: title = "重新框选"; action = { [weak self] in self?.start(mode) }
                    }
                }
                panel.onAction = action
                panel.showError(error.localizedDescription, original: original, actionTitle: title)
            }
        }
    }
}
