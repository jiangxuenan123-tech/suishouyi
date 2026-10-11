import Foundation

@main struct ContractChecks {
    static func main() throws {
        func check(_ value: Bool, _ label: String) { if !value { fatalError(label) } }
        let envelope = Data(#"[{"type":"assistant","message":{"thinking":"private"}},{"type":"result","subtype":"success","is_error":false,"result":"正确译文","providerData":{"model":"hy3"}}]"#.utf8)
        do { let result = try AIContract.response(envelope); check(result.text == "正确译文", "only final result"); check(result.actualModelId == "hy3", "actual source") }
        catch { print("FAIL: expected final success envelope to decode, got \(error)"); exit(1) }
        for raw in [#"{"type":"result","subtype":"error","is_error":true,"result":"错误内容"}"#, #"{"arbitrary":{"result":"不能显示"}}"#, "not-json", #"{"type":"result","subtype":"success","result":""}"#] {
            do { _ = try AIContract.response(Data(raw.utf8)); fatalError("accepted invalid envelope") } catch {}
        }
        let tagged = Data(#"{"type":"result","subtype":"success","result":"<user_query>正在探索 10 个文件，2 次搜索</user_query>"}"#.utf8)
        let taggedResult = try AIContract.response(tagged)
        check(taggedResult.text == "正在探索 10 个文件，2 次搜索", "internal user_query tags leaked")
        let preserved = try AIContract.response(tagged, preservingUserQueryTags: true)
        check(preserved.text == "<user_query>正在探索 10 个文件，2 次搜索</user_query>", "literal source tags removed")
        let html = Data(#"{"type":"result","subtype":"success","result":"<p>示例</p>\n`x < y`"}"#.utf8)
        let htmlResult = try AIContract.response(html)
        check(htmlResult.text == "<p>示例</p>\n`x < y`", "real code modified")
        for kind in ["term", "sentence", "paragraph"] {
            let value = try AIContract.explanation("{\"status\":\"ok\",\"kind\":\"\(kind)\",\"subject\":\"测试\",\"body\":\"通俗解释\"}")
            check(value.kind.rawValue == kind && value.body == "通俗解释", "three input types")
        }
        do { _ = try AIContract.explanation(#"{"status":"wrong","kind":"term","subject":"x","body":"x"}"#); fatalError("invalid status") } catch {}
        check("👩‍💻e\u{301}".count == 2, "Unicode fixture")
        check(AIContract.models("--model <model> Currently supported: (hy3, hy3-x, hy3)\n --fallback-model <model> fallback") == ["hy3", "hy3-x"], "parse and dedupe model IDs")
        check(AIContract.translationBody("Windows", original: "Windows").contains("处理完成"), "unchanged Latin input lacks feedback")
        check(AIContract.translationBody("你好", original: "你好").contains("原文已是中文"), "Chinese input lacks feedback")
        check(AIContract.translationBody("窗户", original: "windows") == "窗户", "changed translation gained notice")
        check(AIContract.translationBody("<p>x</p>", original: "<p>x</p>").hasPrefix("<p>x</p>\n"), "code source modified")
        print("PASS: final envelope, rejected errors, three explanation types, Unicode and model catalog")
    }
}
