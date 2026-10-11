import Foundation
import Darwin

@main struct SetupChecks {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let archive = root.appendingPathComponent("sample.tar.gz")
        try Data("abc".utf8).write(to: archive)
        let sha = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        try DependencyInstaller.verify(archive: archive, checksums: sha + "  sample.tar.gz\n", filename: "sample.tar.gz")
        for manifest in [String(repeating: "0", count: 64) + "  sample.tar.gz", sha + "  another.tar.gz", "invalid  sample.tar.gz"] {
            do {
                try DependencyInstaller.verify(archive: archive, checksums: manifest, filename: "sample.tar.gz")
                fatalError("未阻止错误或缺失 SHA256")
            } catch {}
        }
        let binary = root.appendingPathComponent("codebuddy")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: binary)
        assert(DependencyInstaller.existingCLI(candidates: [binary.path]) == nil)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)
        assert(DependencyInstaller.existingCLI(candidates: [root.appendingPathComponent("missing").path, binary.path]) == binary.path)
        let incompatible = await DependencyInstaller.isCompatibleCLI(binary.path)
        assert(!incompatible, "可执行但缺失官方参数的 CLI 不得视为兼容")
        let required = "--print --output-format --tools --strict-mcp-config --no-session-persistence --model"
        try Data(("#!/bin/sh\nif [ \"$1\" = --help ]; then echo '" + required + "'; fi\n").utf8).write(to: binary)
        let compatible = await DependencyInstaller.isCompatibleCLI(binary.path)
        assert(compatible, "支持全部依赖参数的 CLI 应复用")
        try Data("#!/bin/sh\necho '--print --output-format --tools --no-session-persistence --model'\n".utf8).write(to: binary)
        let missingMCP = await DependencyInstaller.isCompatibleCLI(binary.path)
        assert(!missingMCP, "缺少严格 MCP 参数的旧 CLI 不得复用")
        let oldBinary = try Data(contentsOf: binary)
        let replacement = root.appendingPathComponent("replacement")
        try Data("new managed binary".utf8).write(to: replacement)
        try DependencyInstaller.placeBinary(replacement, at: binary)
        let installedBinary = try Data(contentsOf: binary)
        assert(installedBinary == Data("new managed binary".utf8))
        let backups = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("codebuddy.backup-") }
        assert(backups.count == 1)
        let backupBinary = try Data(contentsOf: backups[0])
        assert(backupBinary == oldBinary, "仅替换自管文件，保留旧副本")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)
        let originalPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        setenv("PATH", root.path + ":" + originalPath, 1)
        defer { setenv("PATH", originalPath, 1) }
        let pathCandidates = DependencyInstaller.candidates.filter { $0.hasPrefix(root.path + "/") }
        let resolved = try CodeBuddyClient.executable(candidates: pathCandidates)
        assert(resolved == binary.path, "安装和翻译必须共用任意 PATH 目录中的 CLI")
        do {
            _ = try CodeBuddyClient.executable(candidates: [root.appendingPathComponent("missing").path])
            fatalError("不存在的 CLI 必须提示组件未安装")
        } catch AIError.missingCLI {}
        let output = try await DependencyInstaller.run("/bin/sh", ["-c", "printf json; printf warning >&2"])
        assert(output == "json", "标准错误不得混入 JSON 响应")
        do {
            _ = try await DependencyInstaller.run("/bin/sh", ["-c", "exit 7"])
            fatalError("必须拒绝 CLI 非零退出")
        } catch {}
        let start = Date()
        do {
            _ = try await DependencyInstaller.run("/bin/sleep", ["20"], timeout: 0.1)
            fatalError("必须中止超时 CLI")
        } catch {}
        assert(Date().timeIntervalSince(start) < 3, "CLI 超时未及时结束")
        print("SetupChecks: SHA256 校验、CLI 复用、输出隔离、失败和超时处理通过")
    }
}
