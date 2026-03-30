import Foundation

class LLMService {

    static let systemPrompt = """
    You are a speech recognition post-processor. Your ONLY job is to fix obvious speech recognition errors. Rules:
    1. Fix Chinese homophone errors (谐音错误) that are clearly wrong in context.
    2. Fix English technical terms that were incorrectly transcribed as Chinese, for example: 配森→Python, 杰森→JSON, 爪哇→Java, 西加加→C++, 杰爱斯→JS, 瑞阿克特→React, 诺德→Node, 吉特→Git, 吉特哈布→GitHub, 多克→Docker, 库伯奈提斯→Kubernetes, 艾皮爱→API, 优阿尔艾尔→URL, 爱奇迪皮→HTTP.
    3. NEVER rewrite, rephrase, polish, or reorganize the text.
    4. NEVER add or remove punctuation beyond what's needed for a fix.
    5. NEVER delete any content that looks correct.
    6. If the input looks correct, return it EXACTLY as-is with zero changes.
    7. Return ONLY the corrected text, no explanations.
    """

    func refine(_ text: String, completion: @escaping (String) -> Void) {
        let settings = Settings.shared
        guard settings.isLLMConfigured else {
            completion(text)
            return
        }

        let baseURL = settings.llmBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            completion(text)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.llmAPIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "model": settings.llmModel,
            "messages": [
                ["role": "system", "content": LLMService.systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.0,
            "max_tokens": 2048
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                DispatchQueue.main.async { completion(text) }
                return
            }
            let refined = content.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async { completion(refined.isEmpty ? text : refined) }
        }.resume()
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

        URLSession.shared.dataTask(with: request) { data, response, error in
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
