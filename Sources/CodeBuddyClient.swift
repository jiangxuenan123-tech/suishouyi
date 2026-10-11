import Foundation
import Darwin

private final class ProcessCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var pid: pid_t = 0
    private var cancelled = false
    func register(_ child: pid_t) {
        lock.lock(); defer { lock.unlock() }
        pid = child
        if cancelled { kill(-child, SIGKILL) }
    }
    func cancel() {
        lock.lock(); defer { lock.unlock() }
        cancelled = true
        if pid > 0 { kill(-pid, SIGKILL) }
    }
    func finish() -> Bool {
        lock.lock(); defer { lock.unlock() }
        pid = 0
        return cancelled
    }
}
private final class PipeOutput: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    func set(_ value: Data) { lock.lock(); data = value; lock.unlock() }
    func get() -> Data { lock.lock(); defer { lock.unlock() }; return data }
}

enum CodeBuddyClient {
    static func executable(candidates: [String] = DependencyInstaller.candidates) throws -> String {
        guard let path = DependencyInstaller.existingCLI(candidates: candidates) else { throw AIError.missingCLI }
        return path
    }
    static func request(prompt: String, systemPrompt: String, modelId: String) async throws -> CodeBuddyResponse {
        let args = ["--model", modelId, "--print", "--output-format", "json", "--tools", "", "--strict-mcp-config", "--mcp-config", "{\"mcpServers\":{}}", "--no-session-persistence", "--system-prompt", systemPrompt]
        let output = try await run(executable: executable(), arguments: args, input: prompt)
        do { return try AIContract.response(output, preservingUserQueryTags: prompt.contains("<user_query>") || prompt.contains("</user_query>")) }
        catch { throw classify(String(data: output, encoding: .utf8) ?? "", fallback: .malformedResponse) }
    }
    static func classify(_ message: String, fallback: AIError = .network) -> AIError {
        let text = message.lowercased()
        if ["login", "log in", "unauthorized", "not authenticated", "401", "登录"].contains(where: text.contains) { return .loginRequired }
        if ["network", "connection", "fetch failed", "timeout", "网络"].contains(where: text.contains) { return .network }
        if ["model unavailable", "unsupported model", "invalid model", "model not found", "quota", "额度", "403", "429"].contains(where: text.contains) { return .modelUnavailable }
        return fallback
    }
    static func run(executable: String, arguments: [String], input: String = "", timeout: TimeInterval = 45) async throws -> Data {
        let cancellation = ProcessCancellation()
        return try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            let result = try await Task.detached { try runSync(executable, arguments, input, timeout, cancellation) }.value
            try Task.checkCancellation()
            return result
        }, onCancel: { cancellation.cancel() })
    }
    private static func runSync(_ executable: String, _ arguments: [String], _ input: String, _ timeout: TimeInterval, _ cancellation: ProcessCancellation) throws -> Data {
        signal(SIGPIPE, SIG_IGN)
        let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        posix_spawn_file_actions_init(&actions); posix_spawnattr_init(&attributes)
        defer { posix_spawn_file_actions_destroy(&actions); posix_spawnattr_destroy(&attributes) }
        posix_spawn_file_actions_adddup2(&actions, stdin.fileHandleForReading.fileDescriptor, STDIN_FILENO)
        posix_spawn_file_actions_adddup2(&actions, stdout.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&actions, stderr.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
        for fd in [stdin.fileHandleForWriting.fileDescriptor, stdout.fileHandleForReading.fileDescriptor, stderr.fileHandleForReading.fileDescriptor] { posix_spawn_file_actions_addclose(&actions, fd) }
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("Suishouyi-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }
        posix_spawn_file_actions_addchdir(&actions, work.path)
        posix_spawnattr_setpgroup(&attributes, 0)
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP))
        let argv = ([executable] + arguments).map { strdup($0) } + [nil]
        defer { for pointer in argv { free(pointer) } }
        var child: pid_t = 0
        let code = argv.withUnsafeBufferPointer { posix_spawn(&child, executable, &actions, &attributes, $0.baseAddress!, environ) }
        guard code == 0 else { throw AIError.missingCLI }
        cancellation.register(child)
        stdin.fileHandleForReading.closeFile(); stdout.fileHandleForWriting.closeFile(); stderr.fileHandleForWriting.closeFile()
        let output = PipeOutput(), errors = PipeOutput(), drains = DispatchGroup()
        drains.enter()
        DispatchQueue.global().async { output.set(stdout.fileHandleForReading.readDataToEndOfFile()); drains.leave() }
        drains.enter()
        DispatchQueue.global().async { errors.set(stderr.fileHandleForReading.readDataToEndOfFile()); drains.leave() }
        drains.enter()
        DispatchQueue.global().async { try? stdin.fileHandleForWriting.write(contentsOf: Data(input.utf8)); try? stdin.fileHandleForWriting.close(); drains.leave() }
        var status: Int32 = 0
        let deadline = Date().addingTimeInterval(timeout)
        var timedOut = false
        while waitpid(child, &status, WNOHANG) == 0 {
            if Date() >= deadline { timedOut = true; kill(-child, SIGKILL); waitpid(child, &status, 0); break }
            Thread.sleep(forTimeInterval: 0.02)
        }
        kill(-child, SIGKILL)
        let wasCancelled = cancellation.finish()
        drains.wait()
        if wasCancelled { throw CancellationError() }
        if timedOut { throw AIError.timeout }
        if status != 0 { throw classify(String(data: errors.get() + output.get(), encoding: .utf8) ?? "") }
        return output.get()
    }
}
