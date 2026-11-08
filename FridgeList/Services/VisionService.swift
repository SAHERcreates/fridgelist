import Foundation

/// Ошибки распознавания с понятными сообщениями для пользователя.
enum VisionError: LocalizedError {
    case missingAPIKey
    case invalidBaseURL
    case httpError(status: Int, message: String)
    case unexpectedResponse(detail: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Не задан API-ключ. Откройте «Настройки» и добавьте ключ или включите демо-режим."
        case .invalidBaseURL:
            return "Некорректный адрес сервиса в настройках."
        case .httpError(let status, let message):
            return "Сервис вернул ошибку \(status): \(message)"
        case .unexpectedResponse(let detail):
            return "Не удалось разобрать ответ сервиса. Ответ: \(detail)"
        }
    }
}

protocol VisionService {
    /// Возвращает список продуктов, распознанных на фото холодильника.
    func recognizeProducts(in imageData: Data) async throws -> [String]
}

/// Демо-сервис для проверки приложения без API-ключа.
struct MockVisionService: VisionService {
    func recognizeProducts(in imageData: Data) async throws -> [String] {
        try await Task.sleep(for: .seconds(1.2))
        return ["Молоко", "Яйца", "Сыр", "Яблоки", "Кефир", "Помидоры"]
    }
}

/// Клиент OpenAI-совместимого Chat Completions API с поддержкой изображений.
struct OpenAIVisionService: VisionService {
    let settings: AppSettings

    private static let prompt = """
    Это фото содержимого холодильника. Перечисли все продукты питания, которые видишь.
    Верни строго JSON-объект вида {"products": ["молоко", "яйца"]}.
    Правила: названия по-русски, в именительном падеже, без брендов, без количества,
    каждый продукт один раз. Никакого текста кроме JSON.
    """

    func recognizeProducts(in imageData: Data) async throws -> [String] {
        let apiKey = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { throw VisionError.missingAPIKey }
        guard let url = URL(string: settings.baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
                                .appending("/chat/completions")) else {
            throw VisionError.invalidBaseURL
        }

        let requestBody = ChatRequest(
            model: settings.model,
            messages: [
                .init(role: "user", content: [
                    .text(Self.prompt),
                    .imageData(imageData, mimeType: "image/jpeg"),
                ]),
            ],
            maxTokens: 600
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw VisionError.unexpectedResponse(detail: "нет HTTP-ответа")
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(APIErrorEnvelope.self, from: data))?.error.message
                ?? String(data: data.prefix(300), encoding: .utf8)
                ?? "нет описания"
            throw VisionError.httpError(status: http.statusCode, message: message)
        }

        let decoded: ChatResponse
        do {
            decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            let snippet = String(data: data.prefix(300), encoding: .utf8) ?? "нечитаемый ответ"
            throw VisionError.unexpectedResponse(detail: snippet)
        }
        guard let rawContent = decoded.choices.first?.message.content else {
            let snippet = String(data: data.prefix(300), encoding: .utf8) ?? "нечитаемый ответ"
            throw VisionError.unexpectedResponse(detail: snippet)
        }
        return Self.parseProducts(from: rawContent.stringValue)
    }

    /// Достаёт массив продуктов из ответа модели, даже если тот обёрнут в ```json.
    static func parseProducts(from content: String) -> [String] {
        var text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            text = String(text[start...end])
        }
        struct Products: Decodable { let products: [String] }
        guard let data = text.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(Products.self, from: data)
        else { return [] }

        var seen = Set<String>()
        return parsed.products
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert(ProductMatcher.normalize($0)).inserted }
    }
}

// MARK: - Модели запроса/ответа

private struct ChatRequest: Encodable {
    struct Message: Encodable {
        enum Content: Encodable {
            case text(String)
            case imageData(Data, mimeType: String)

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                switch self {
                case .text(let text):
                    try container.encode("text", forKey: .type)
                    try container.encode(text, forKey: .text)
                case .imageData(let data, let mimeType):
                    try container.encode("image_url", forKey: .type)
                    let dataURL = "data:\(mimeType);base64,\(data.base64EncodedString())"
                    try container.encode(ImageURL(url: dataURL), forKey: .imageURL)
                }
            }

            struct ImageURL: Encodable { let url: String }

            enum CodingKeys: String, CodingKey {
                case type, text
                case imageURL = "image_url"
            }
        }

        let role: String
        let content: [Content]
    }

    let model: String
    let messages: [Message]
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model, messages
        case maxTokens = "max_tokens"
    }
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            /// Поле content может быть строкой, массивом частей или null.
            let content: Content?

            enum Content: Decodable {
                struct Part: Decodable {
                    let type: String?
                    let text: String?
                }
                case text(String)
                case parts([Part])

                var stringValue: String {
                    switch self {
                    case .text(let s): return s
                    case .parts(let parts): return parts.compactMap(\.text).joined()
                    }
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    if let s = try? container.decode(String.self) {
                        self = .text(s)
                    } else if let p = try? container.decode([Part].self) {
                        self = .parts(p)
                    } else {
                        self = .text("")
                    }
                }
            }
        }
        let message: Message
    }
    let choices: [Choice]
}

private struct APIErrorEnvelope: Decodable {
    struct APIError: Decodable { let message: String }
    let error: APIError
}
