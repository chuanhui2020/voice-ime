import Foundation

class LLMService {

    private static let maxLogEntries = 100
    private static let maxHistoryEntries = 10
    private static let historyExpirySeconds: TimeInterval = 600 // 10 minutes

    private struct ConversationEntry {
        let userText: String
        let assistantText: String
        let timestamp: Date
    }

    private var history: [ConversationEntry] = []

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.httpShouldUsePipelining = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    private static var logFileURL: URL = {
        // When running as .app bundle (make run), use bundle's parent directory
        // When running via swift run, use current directory
        let base: URL
        if let bundlePath = Bundle.main.bundleURL.path.components(separatedBy: ".app").first,
           bundlePath != Bundle.main.bundleURL.path {
            base = URL(fileURLWithPath: bundlePath).deletingLastPathComponent()
        } else {
            base = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        }
        let dir = base.appendingPathComponent("logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("llm_log.jsonl")
    }()

    private static func appendLog(_ entry: [String: Any]) {
        var entry = entry
        let formatter = ISO8601DateFormatter()
        entry["timestamp"] = formatter.string(from: Date())

        guard let data = try? JSONSerialization.data(withJSONObject: entry),
              let line = String(data: data, encoding: .utf8) else { return }

        // Read existing lines
        var lines: [String] = []
        if let content = try? String(contentsOf: logFileURL, encoding: .utf8) {
            lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        }

        lines.append(line)

        // Keep only last maxLogEntries
        if lines.count > maxLogEntries {
            lines = Array(lines.suffix(maxLogEntries))
        }

        let output = lines.joined(separator: "\n") + "\n"
        try? output.write(to: logFileURL, atomically: true, encoding: .utf8)
    }

    static func systemPrompt(locale: String) -> String {
        let langHint: String
        switch locale {
        case "zh-CN": langHint = "简体中文"
        case "zh-TW": langHint = "繁体中文"
        case "ja-JP": langHint = "日语"
        case "ko-KR": langHint = "韩语"
        default: langHint = "英语"
        }

        return """
        你是一个语音识别纠错助手。用户正在使用\(langHint)语音输入，下面的文本是语音识别引擎的原始输出，可能包含错误。

        你的任务：
        1. 【最重要】修复被错误转写为中文的英文单词。语音识别引擎经常把英文单词按发音转写成中文，你需要根据发音和上下文还原为正确的英文。常见模式：
           - 编程语言：配森/派森→Python，杰森→JSON，爪哇→Java，西加加/C加加→C++，斯威夫特→Swift，科特林→Kotlin，拉斯特→Rust，泰普斯克里普特→TypeScript
           - 工具框架：瑞阿克特/瑞艾克特→React，诺德→Node，吉特→Git，吉特哈布→GitHub，多克/道克→Docker，库伯奈提斯→Kubernetes，恩金艾克斯→Nginx，瑞迪斯→Redis
           - 通用术语：艾皮爱/爱皮爱→API，优阿尔艾尔→URL，爱奇迪皮→HTTP，埃斯克尤艾尔→SQL，西艾尔爱→CLI，艾斯蒂开→SDK，哈希→Hash，托肯→Token，瑟沃→Server，克莱恩特→Client
           - 以上只是示例，任何听起来像英文的中文音译都应该还原。根据发音相似度和上下文判断。
        2. 修复明显的同音字错误（如"已经"写成"以经"，"那里"写成"哪里"等）。
        3. 修复明显不合理的断句和标点。
        4. 不要改写、润色、重组句子结构，不要删除任何看起来正确的内容。
        5. 只返回修正后的文本，不要任何解释。

        示例：
        输入：我用配森写了一个爱皮爱接口，部署在多克容器里
        输出：我用Python写了一个API接口，部署在Docker容器里

        输入：这个杰森文件的格式不对，需要用诺德杰爱斯来解析
        输出：这个JSON文件的格式不对，需要用Node.js来解析

        输入：我们用瑞阿克特做前端吉特哈布上有代码
        输出：我们用React做前端，GitHub上有代码

        输入：把这个数据库的埃斯克尤艾尔查询优化一下
        输出：把这个数据库的SQL查询优化一下

        注意：对话历史中包含之前的语音输入（user）和你的修正结果（assistant）。请利用这些上下文来辅助纠错，例如前文提到过的专有名词、技术术语等，在后续输入中应保持一致的识别。
        """
    }

    @discardableResult
    func refine(_ text: String, locale: String, completion: @escaping (String) -> Void) -> URLSessionDataTask? {
        let settings = Settings.shared
        guard settings.isLLMConfigured else {
            completion(text)
            return nil
        }

        let baseURL = settings.llmBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            completion(text)
            return nil
        }

        // Purge expired history
        let now = Date()
        history.removeAll { now.timeIntervalSince($0.timestamp) > LLMService.historyExpirySeconds }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.llmAPIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        // Build messages with conversation history
        var messages: [[String: String]] = [
            ["role": "system", "content": LLMService.systemPrompt(locale: locale)]
        ]
        for entry in history {
            messages.append(["role": "user", "content": entry.userText])
            messages.append(["role": "assistant", "content": entry.assistantText])
        }
        messages.append(["role": "user", "content": text])

        let body: [String: Any] = [
            "model": settings.llmModel,
            "messages": messages,
            "temperature": 0.0,
            "max_tokens": 2048
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let historyCount = history.count
        return sendRequest(request, text: text, locale: locale, historyCount: historyCount, retriesLeft: 3, completion: completion)
    }

    private static let maxRetries = 3

    private func sendRequest(_ request: URLRequest, text: String, locale: String, historyCount: Int, retriesLeft: Int, completion: @escaping (String) -> Void) -> URLSessionDataTask {
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                let nsError = error as NSError
                // Retry on network connection lost (-1005) or timed out (-1001)
                if retriesLeft > 0 && (nsError.code == -1005 || nsError.code == -1001) {
                    let attempt = LLMService.maxRetries - retriesLeft + 1
                    let delay = 0.5 * pow(2.0, Double(attempt - 1)) // 0.5s, 1s, 2s
                    LLMService.appendLog([
                        "type": "retry",
                        "input": text,
                        "locale": locale,
                        "error": error.localizedDescription,
                        "attempt": attempt,
                        "delay": delay
                    ])
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        _ = self?.sendRequest(request, text: text, locale: locale, historyCount: historyCount, retriesLeft: retriesLeft - 1, completion: completion)
                    }
                    return
                }
                LLMService.appendLog([
                    "type": "error",
                    "input": text,
                    "locale": locale,
                    "error": error.localizedDescription
                ])
                DispatchQueue.main.async { completion(text) }
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "no data"
                LLMService.appendLog([
                    "type": "error",
                    "input": text,
                    "locale": locale,
                    "error": "parse failed",
                    "response_body": body
                ])
                DispatchQueue.main.async { completion(text) }
                return
            }
            let refined = content.trimmingCharacters(in: .whitespacesAndNewlines)
            let result = refined.isEmpty ? text : refined
            // Record to conversation history
            self?.history.append(ConversationEntry(userText: text, assistantText: result, timestamp: Date()))
            if let count = self?.history.count, count > LLMService.maxHistoryEntries {
                self?.history.removeFirst(count - LLMService.maxHistoryEntries)
            }
            LLMService.appendLog([
                "type": "success",
                "input": text,
                "output": result,
                "locale": locale,
                "changed": text != result,
                "history_count": historyCount
            ])
            DispatchQueue.main.async { completion(result) }
        }
        task.resume()
        return task
    }

    func testConnection(baseURL: String, apiKey: String, model: String, completion: @escaping (Bool, String) -> Void) {
        let cleanURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(cleanURL)/chat/completions") else {
            completion(false, "Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": "Hi"]],
            "max_tokens": 5
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(false, error.localizedDescription) }
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(false, "No response") }
                return
            }
            if httpResponse.statusCode == 200 {
                DispatchQueue.main.async { completion(true, "Connection successful!") }
            } else {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
                DispatchQueue.main.async { completion(false, "HTTP \(httpResponse.statusCode): \(body)") }
            }
        }.resume()
    }
}
