import Foundation

enum TaskMode: String { case translation, explanation }
enum ExplanationKind: String, Codable { case term, sentence, paragraph }
struct Explanation: Codable {
    let status: String
    let kind: ExplanationKind
    let subject: String
    let body: String
}
struct CodeBuddyResponse { let text: String; let actualModelId: String? }
struct AIResult {
    let body: String
    let originalText: String
    let source: String
    let requestedModelId: String?
    let actualModelId: String?
    let mode: TaskMode
    let kind: ExplanationKind?
}
enum AIError: Error, LocalizedError {
    case missingCLI, loginRequired, modelUnavailable, network, timeout, malformedResponse, tooLong
    var errorDescription: String? {
        switch self {
        case .missingCLI: return "AI 组件尚未安装，请打开使用准备。"
        case .loginRequired: return "CodeBuddy 登录已失效，请重新登录后重试。"
        case .modelUnavailable: return "当前模型不可用或额度不足，请切换模型后重试。"
        case .network: return "暂时无法连接 AI，请检查网络后重试。"
        case .timeout: return "AI 响应超时，原文已保留，可以重试。"
        case .malformedResponse: return "AI 没有返回完整结果，可以重试。"
        case .tooLong: return "解释无法压缩到 100 字以内，请重试或缩小范围。"
        }
    }
}
enum AIContract {
    static func response(_ data: Data, preservingUserQueryTags: Bool = false) throws -> CodeBuddyResponse {
        let raw = try JSONSerialization.jsonObject(with: data)
        let records = (raw as? [[String: Any]]) ?? [(raw as? [String: Any]) ?? [:]]
        guard let record = records.last(where: { $0["type"] as? String == "result" }),
              record["subtype"] as? String == "success", record["is_error"] as? Bool != true,
              let text = record["result"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AIError.malformedResponse }
        let provider = record["providerData"] as? [String: Any]
        let body = (preservingUserQueryTags ? text : text.replacingOccurrences(of: "<user_query>", with: "").replacingOccurrences(of: "</user_query>", with: "")).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { throw AIError.malformedResponse }
        return CodeBuddyResponse(text: body, actualModelId: provider?["model"] as? String)
    }
    static func translationBody(_ body: String, original: String) -> String {
        guard body.trimmingCharacters(in: .whitespacesAndNewlines) == original.trimmingCharacters(in: .whitespacesAndNewlines) else { return body }
        let chinese = original.range(of: "[\\u3400-\\u9FFF]", options: .regularExpression) != nil && original.range(of: "[A-Za-z]", options: .regularExpression) == nil
        return body + "\n\n（" + (chinese ? "原文已是中文，无需另译。" : "处理完成，结果与原文一致。专有名称和代码可能无需翻译；若要确定含义，请截取完整句子或切换解释。") + "）"
    }
    static func explanation(_ text: String) throws -> Explanation {
        guard let data = text.data(using: .utf8), let result = try? JSONDecoder().decode(Explanation.self, from: data),
              ["ok", "uncertain", "needs_selection"].contains(result.status), !result.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AIError.malformedResponse }
        return result
    }
    static func models(_ help: String) -> [String] {
        guard let line = help.components(separatedBy: .newlines).first(where: { $0.contains("--model <model>") }),
              let start = line.range(of: "supported: ("), let end = line[start.upperBound...].firstIndex(of: ")") else { return [] }
        var seen = Set<String>()
        return line[start.upperBound..<end].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
