import AppKit
import ApplicationServices

@MainActor final class SetupCoordinator: NSObject {
    private var window: NSWindow?
    private let dependency = NSTextField(wrappingLabelWithString: "正在检查翻译组件…")
    private let account = NSTextField(wrappingLabelWithString: "等待检查账号…")
    private let accessibility = NSTextField(labelWithString: "")
    private let screen = NSTextField(labelWithString: "")
    private let demonstration = NSTextField(wrappingLabelWithString:
        "试一次：选中一段文字 → 按翻译快捷键（默认 ⌥D） → 点「复制」。解释快捷键默认 ⌥E；可在菜单栏设置里修改。")
    private var checking = false
    private var installation: Task<String, Error>?

    func show() {
        if window == nil { makeWindow() }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        checkPermissions()
        check()
    }
    func installCLI() async throws -> String {
        if let installation { return try await installation.value }
        let task = Task { try await DependencyInstaller.install() }
        installation = task
        defer { installation = nil }
        return try await task.value
    }
    func login() {
        Task { @MainActor in
            do {
                let executable = try await installCLI()
                let folder = DependencyInstaller.directory
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let command = folder.appendingPathComponent("登录CodeBuddy.command")
                func quote(_ text: String) -> String { "'" + text.replacingOccurrences(of: "'", with: "'\"'\"'") + "'" }
                let script = "#!/bin/sh\ncd " + quote(folder.path) + "\nexec " + quote(executable)
                    + " --tools '' --strict-mcp-config --mcp-config '{\"mcpServers\":{}}' --no-session-persistence /login\n"
                try script.write(to: command, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: command.path)
                let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
                _ = try await NSWorkspace.shared.open([command], withApplicationAt: terminal,
                    configuration: NSWorkspace.OpenConfiguration())
                account.stringValue = "已打开官方登录窗口。选择 Chinese Site，完成浏览器授权后回来点「检查并继续」。"
            } catch { account.stringValue = error.localizedDescription }
        }
    }
    @objc private func loginAction() { login() }
    @objc private func checkAction() { checkPermissions(); check(verifyAccount: true) }
    @objc private func accessibilityAction() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openSettings("Privacy_Accessibility")
    }
    @objc private func screenAction() {
        _ = CGRequestScreenCaptureAccess()
        openSettings("Privacy_ScreenCapture")
    }
    @objc private func closeAction() { window?.orderOut(nil) }
    @objc private func active() { checkPermissions() }
    private func openSettings(_ pane: String) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?" + pane)!)
    }
    private func checkPermissions() {
        accessibility.stringValue = "辅助功能：" + (AXIsProcessTrusted() ? "已允许，可读取选中文字" : "需要本人允许，用于读取选中文字")
        screen.stringValue = "屏幕录制：" + (CGPreflightScreenCaptureAccess() ? "已允许，可框选截图识字" : "需要本人允许，用于框选截图识字")
    }
    private func check(verifyAccount: Bool = false) {
        guard !checking else { return }
        checking = true
        Task { @MainActor in
            defer { checking = false }
            do {
                dependency.stringValue = "正在检查翻译组件；需要时自动从官方源下载并校验 SHA256…"
                let executable = try await installCLI()
                dependency.stringValue = "翻译组件：已就绪（自动复用或安装，无需 Node.js）"
                guard verifyAccount else {
                    account.stringValue = "点击「检查并继续」验证本人账号；首次使用请先完成官方登录。"
                    return
                }
                let model = AppSettings.shared.modelId
                account.stringValue = "正在验证本人账号和模型 \(model) 是否可用…"
                let output = try await DependencyInstaller.run(executable, ["--model", model, "--print",
                    "--output-format", "json", "--tools", "", "--strict-mcp-config", "--mcp-config",
                    "{\"mcpServers\":{}}", "--no-session-persistence", "--setting-sources", "user",
                    "--system-prompt", "只回答 OK。", "只回答 OK。"])
                guard let data = output.data(using: .utf8) else {
                    throw DependencyInstaller.Failure(message: "暂时无法验证账号。请完成官方登录，或检查网络与额度后重试。")
                }
                let response = try AIContract.response(data)
                account.stringValue = "本人账号：模型 \(response.actualModelId ?? model) 已验证可用"
                demonstration.isHidden = false
            } catch {
                if DependencyInstaller.existingCLI() == nil {
                    dependency.stringValue = "翻译组件：安装未完成。" + error.localizedDescription
                    account.stringValue = "组件安装成功后即可登录。"
                } else {
                    account.stringValue = "本人账号：尚未验证可用。请完成官方登录；已有登录时请检查网络和额度，再点「检查并继续」。"
                }
            }
        }
    }
    private func button(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }
    private func makeWindow() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 600),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "随手译 · 首次设置"
        window.isReleasedWhenClosed = false
        let title = NSTextField(labelWithString: "准备好，就能随手翻译")
        title.font = .boldSystemFont(ofSize: 23)
        let explanation = NSTextField(wrappingLabelWithString:
            "翻译组件会自动安装。首次登录和 Mac 隐私权限需要本人确认。账号由 CodeBuddy 官方保存，随手译不会读取或复制登录凭据。")
        let login = button("登录本人 CodeBuddy 账号", #selector(loginAction))
        let ax = button("打开辅助功能设置", #selector(accessibilityAction))
        let capture = button("打开屏幕录制设置", #selector(screenAction))
        let check = button("检查并继续", #selector(checkAction))
        let close = button("返回翻译", #selector(closeAction))
        let footer = NSTextField(wrappingLabelWithString:
            "授权后回到这里检查；系统若要求重新打开应用，请退出后再打开随手译。账号检查会发出一次很短的当前模型请求，用于确认登录、网络与额度。")
        footer.textColor = .secondaryLabelColor
        footer.font = .systemFont(ofSize: 12)
        demonstration.isHidden = true
        let actions = NSStackView(views: [check, close])
        actions.orientation = .horizontal
        let stack = NSStackView(views: [title, explanation, dependency, account, login,
            accessibility, ax, screen, capture, footer, demonstration, actions])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 24)
        ])
        for field in [explanation, dependency, account, footer, demonstration] {
            field.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        self.window = window
        NotificationCenter.default.addObserver(self, selector: #selector(active),
            name: NSApplication.didBecomeActiveNotification, object: nil)
    }
}
