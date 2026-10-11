import Foundation

@main struct TranslationMeaningChecks {
    static func main() async throws {
        let samples: [(String, [String])] = [
            ("Windows", ["系统", "窗"]),
            ("API", ["API", "接口"]),
            ("MCP", ["MCP", "上下文"]),
            ("QZXV", ["QZXV"]),
            ("Open the windows.", ["窗"]),
            ("Use the API to exchange data.", ["API", "接口"]),
            ("你好", ["原文已是中文"]),
            ("<user_query>Hello</user_query>", ["<user_query>", "</user_query>"])
        ]
        for (text, expected) in samples {
            let result = try await Translator.shared.process(text, mode: .translation, modelId: "hy3")
            FileHandle.standardOutput.write(Data(("HY3 " + text + " → " + result.body + "\n").utf8))
            precondition(result.source == "ai" && result.originalText == text)
            precondition(expected.allSatisfy(result.body.contains))
            if text == "QZXV" { precondition(["无法确定", "不确定", "上下文"].contains(where: result.body.contains)) }
            if text == "Open the windows." { precondition(!result.body.contains("微软")) }
            if !text.contains("<user_query>") { precondition(!result.body.contains("<user_query>")) }
        }
        print("PASS: standalone words, acronyms, uncertainty, context, Chinese feedback and source code")
    }
}
