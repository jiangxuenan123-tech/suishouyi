import Foundation
import CryptoKit

// 官方原生 CLI；只写当前用户的应用支持目录。
enum DependencyInstaller {
    static let repository = "https://acc-1258344699.cos.accelerate.myqcloud.com/@tencent-ai/codebuddy-code/releases"
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("随手译/CodeBuddy", isDirectory: true)
    }
    static var candidates: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [directory.appendingPathComponent("codebuddy").path, "\(home)/.local/bin/codebuddy", "/opt/homebrew/bin/codebuddy", "/usr/local/bin/codebuddy"]
            + (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { "\($0)/codebuddy" }
    }
    static func existingCLI(candidates: [String] = candidates) -> String? {
        candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    static func verify(archive: URL, checksums: String, filename: String) throws {
        let expected = checksums.split(whereSeparator: \.isNewline).compactMap { line -> String? in
            let fields = line.split(whereSeparator: \.isWhitespace)
            return fields.count == 2 && fields[1] == filename ? String(fields[0]) : nil
        }.first
        let actual = SHA256.hash(data: try Data(contentsOf: archive, options: .mappedIfSafe))
            .map { String(format: "%02x", $0) }.joined()
        guard expected == actual else {
            throw Failure(message: "CodeBuddy 安装包 SHA256 校验失败，已停止安装。请重试。")
        }
    }
    static func isCompatibleCLI(_ path: String) async -> Bool {
        guard let help = try? await run(path, ["--help"], timeout: 15) else { return false }
        return ["--print", "--output-format", "--tools", "--strict-mcp-config", "--no-session-persistence", "--model"]
            .allSatisfy { help.contains($0) }
    }
    static func placeBinary(_ source: URL, at destination: URL) throws {
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: source,
                backupItemName: destination.lastPathComponent + ".backup-" + UUID().uuidString,
                options: .withoutDeletingBackupItem)
        } else {
            try FileManager.default.moveItem(at: source, to: destination)
        }
    }
    static func text(from url: URL) async throws -> String {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let value = String(data: data, encoding: .utf8) else {
            throw Failure(message: "无法读取官方 CodeBuddy 发布信息。请检查网络后重试。")
        }
        return value
    }
    static func install() async throws -> String {
        if let path = existingCLI(), await isCompatibleCLI(path) { return path }
        let version = try await text(from: URL(string: repository + "/latest")!)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard version.range(of: #"^\d+\.\d+\.\d+([-+][A-Za-z0-9.-]+)?$"#, options: .regularExpression) != nil else {
            throw Failure(message: "官方 CodeBuddy 发布版本无法识别。")
        }
        var translated: Int32 = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname("sysctl.proc_translated", &translated, &size, nil, 0)
        #if arch(arm64)
        let arch = "arm64"
        #else
        let arch = translated == 1 ? "arm64" : "x86_64"
        #endif
        let name = "codebuddy-code_Darwin_\(arch).tar.gz"
        let base = repository + "/download/\(version)/"
        let checksums = try await text(from: URL(string: base + "checksums.txt")!)
        let (download, response) = try await URLSession.shared.download(from: URL(string: base + name)!)
        defer { try? FileManager.default.removeItem(at: download) }
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw Failure(message: "CodeBuddy 下载失败。请检查网络后重试。")
        }
        try verify(archive: download, checksums: checksums, filename: name)
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        _ = try await run("/usr/bin/tar", ["-xzf", download.path, "-C", temporary.path, "codebuddy"])
        let source = temporary.appendingPathComponent("codebuddy")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: source.path)
        _ = try await run(source.path, ["--version"])
        guard await isCompatibleCLI(source.path) else {
            throw Failure(message: "官方 CodeBuddy 组件暂不支持所需参数，已停止安装。")
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("codebuddy")
        try placeBinary(source, at: destination)
        let receipt: [String: String] = ["version": version, "archive": name, "source": base + name,
            "sha256": SHA256.hash(data: try Data(contentsOf: download, options: .mappedIfSafe)).map { String(format: "%02x", $0) }.joined(),
            "verification": "official checksums.txt SHA256 matched"]
        try JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("installation.json"), options: .atomic)
        return destination.path
    }
    static func run(_ executable: String, _ arguments: [String], timeout: Double = 45) async throws -> String {
        try await Task.detached {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.currentDirectoryURL = FileManager.default.temporaryDirectory
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            process.standardInput = FileHandle.nullDevice
            try process.run()
            let stop = DispatchWorkItem { if process.isRunning { process.terminate() } }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: stop)
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            stop.cancel()
            guard process.terminationStatus == 0 else {
                // 不在界面展示 CLI 原始输出，避免泄露账号信息。
                throw Failure(message: "CodeBuddy 检查未完成。请检查网络、账号登录与额度后重试。")
            }
            return String(data: data, encoding: .utf8) ?? ""
        }.value
    }
}
