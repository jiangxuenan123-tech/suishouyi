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
    private var generations: [String: Task<Void, Never>] = [:]
    private var failures: [String: Error] = [:]
    private var requestModels: [String: String] = [:]
    private var revision = 0
    private var displayedResult = false
    private var selectedMode = false
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
        panel.onClose = { [weak self] in self?.cancelGeneration() }
        panel.onCancel = { [weak self] in self?.cancelGeneration(); self?.panel.hidePanel() }
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
    @objc private func quit() { cancelGeneration(); NSApp.terminate(nil) }
    private func cancelGeneration() {
        revision += 1
        activeTask?.cancel(); activeTask = nil
        for task in generations.values { task.cancel() }
        generations.removeAll()
    }
    private func switchMode(_ mode: TaskMode) {
        guard activeTask == nil else { panel.setMode(currentMode); panel.showBusy(); return }
        selectedMode = true; currentMode = mode
        if let result = results[mode.rawValue] { panel.showResult(result) }
        else if generations[mode.rawValue] != nil { panel.showLoading(original: original, mode: mode, modelId: requestModels[mode.rawValue]) }
        else if let error = failures[mode.rawValue] { showFailure(error, mode: mode) }
        else { start(mode, reuse: !original.isEmpty) }
    }
    private func start(_ mode: TaskMode, reuse: Bool = false) {
        guard activeTask == nil else { panel.showBusy(); return }
        if reuse && !original.isEmpty {
            currentMode = mode
            if let result = results[mode.rawValue] { panel.showResult(result); return }
            if generations[mode.rawValue] != nil { panel.showLoading(original: original, mode: mode, modelId: requestModels[mode.rawValue]); return }
            generate(mode, modelId: settings.modelId, revision: revision)
            return
        }
        if !generations.isEmpty && !displayedResult { panel.showBusy(); return }
        cancelGeneration()
        let version = revision, modelId = settings.modelId, both = settings.parallelGeneration
        let app = sourceApp
        currentMode = mode; original = ""; results.removeAll(); failures.removeAll(); requestModels.removeAll()
        displayedResult = false; selectedMode = false
        activeTask = Task { [self] in
            defer { if revision == version { activeTask = nil } }
            do {
                panel.showLoading(original: "", mode: mode, message: "正在获取选中文字…", modelId: modelId)
                if let selected = await SelectionReader.readSelectedText(from: app) {
                    try Task.checkCancellation(); original = selected
                } else {
                    try Task.checkCancellation(); panel.hidePanel()
                    guard let image = try await ScreenOCR.captureInteractiveSelection() else { return }
                    try Task.checkCancellation()
                    panel.showLoading(original: "", mode: mode, message: "正在识别截图中的文字…", modelId: modelId)
                    let text = try await ScreenOCR.recognizeText(in: image)
                    try Task.checkCancellation(); original = text
                }
                guard !original.trimmed.isEmpty else { throw InputError.noText }
                generate(mode, modelId: modelId, revision: version)
                if both { generate(mode == .translation ? .explanation : .translation, modelId: modelId, revision: version) }
            } catch is CancellationError { if revision == version { panel.hidePanel() } }
            catch { if revision == version { showFailure(error, mode: mode) } }
        }
    }
    private func generate(_ mode: TaskMode, modelId: String, revision version: Int) {
        guard generations[mode.rawValue] == nil else { return }
        let text = original
        failures.removeValue(forKey: mode.rawValue); requestModels[mode.rawValue] = modelId
        if mode == currentMode { panel.showLoading(original: text, mode: mode, modelId: modelId) }
        generations[mode.rawValue] = Task { [self] in
            let slow = Task { try? await Task.sleep(nanoseconds: 8_000_000_000); if !Task.isCancelled && revision == version && currentMode == mode { panel.showSlow() } }
            defer { slow.cancel(); if revision == version { generations.removeValue(forKey: mode.rawValue) } }
            do {
                let result = try await Translator.shared.process(text, mode: mode, modelId: modelId)
                try Task.checkCancellation()
                guard revision == version else { return }
                results[mode.rawValue] = result
                if mode == currentMode || (!displayedResult && !selectedMode) {
                    currentMode = mode; displayedResult = true; panel.showResult(result)
                }
            } catch is CancellationError { }
            catch {
                guard revision == version && !Task.isCancelled else { return }
                failures[mode.rawValue] = error
                if mode == currentMode { showFailure(error, mode: mode) }
            }
        }
    }
    private func showFailure(_ error: Error, mode: TaskMode) {
        panel.setMode(mode)
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
