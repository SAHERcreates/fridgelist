import Foundation

/// Настройки подключения к ИИ-сервису распознавания.
/// Совместим с OpenAI-совместимым Chat Completions API
/// (OpenAI, OpenRouter, локальные серверы и т.п.).
@Observable
final class AppSettings {
    private let defaults = UserDefaults.standard

    var baseURLString: String {
        didSet { defaults.set(baseURLString, forKey: Keys.baseURL) }
    }

    var model: String {
        didSet { defaults.set(model, forKey: Keys.model) }
    }

    /// Демо-режим: вместо реального API возвращает пример списка продуктов.
    var useMockService: Bool {
        didSet { defaults.set(useMockService, forKey: Keys.useMock) }
    }

    var apiKey: String {
        didSet { KeychainHelper.saveAPIKey(apiKey) }
    }

    var isConfigured: Bool {
        useMockService || !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init() {
        self.baseURLString = defaults.string(forKey: Keys.baseURL) ?? "https://api.openai.com/v1"
        self.model = defaults.string(forKey: Keys.model) ?? "gpt-4o-mini"
        self.useMockService = defaults.bool(forKey: Keys.useMock)
        self.apiKey = KeychainHelper.loadAPIKey()
    }

    private enum Keys {
        static let baseURL = "settings.baseURL"
        static let model = "settings.model"
        static let useMock = "settings.useMockService"
    }
}
