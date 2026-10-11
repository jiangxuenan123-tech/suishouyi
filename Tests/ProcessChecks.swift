import Foundation

@main struct ProcessChecks {
    static func main() async throws {
        guard case .malformedResponse = CodeBuddyClient.classify("invalid JSON with model metadata", fallback: .malformedResponse) else { fatalError("malformed response mislabeled") }
        guard case .network = CodeBuddyClient.classify("network connection failed, model: hy3", fallback: .malformedResponse) else { fatalError("network mislabeled") }
        guard case .loginRequired = CodeBuddyClient.classify("login expired") else { fatalError("login mislabeled") }
        guard case .modelUnavailable = CodeBuddyClient.classify("unsupported model") else { fatalError("model mislabeled") }
        precondition("這是翻譯與說明。".applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) == "这是翻译与说明。")
        let data = try await CodeBuddyClient.run(executable: "/usr/bin/python3", arguments: ["-c", "import sys;sys.stdout.write('o'*200000);sys.stdout.flush();sys.stderr.write('e'*200000)"])
        guard data.count == 200000 else { fatalError("pipes did not drain") }
        do { _ = try await CodeBuddyClient.run(executable: "/bin/sleep", arguments: ["10"], timeout: 0.1); fatalError("timeout ignored") } catch AIError.timeout {}
        let start = Date()
        let task = Task { try await CodeBuddyClient.run(executable: "/bin/sh", arguments: ["-c", "sleep 20 & wait"]) }
        try await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
        do { _ = try await task.value; fatalError("cancel ignored") } catch is CancellationError {}
        guard Date().timeIntervalSince(start) < 2 else { fatalError("descendant survived cancellation") }
        let echo = try await CodeBuddyClient.run(executable: "/bin/cat", arguments: [], input: "截图内容只通过stdin")
        guard String(data: echo, encoding: .utf8) == "截图内容只通过stdin" else { fatalError("stdin lost") }
        print("PASS: dual pipes, timeout, cancellation with child process, stdin")
    }
}
