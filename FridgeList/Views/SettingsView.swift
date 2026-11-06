import SwiftUI

/// Настройки ИИ-сервиса распознавания.
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section {
                    Toggle("Демо-режим (без API-ключа)", isOn: $settings.useMockService)
                        .accessibilityIdentifier("settings.mockToggle")
                } footer: {
                    Text("В демо-режиме вместо реального распознавания возвращается пример списка продуктов — удобно проверить приложение.")
                }

                Section("ИИ-сервис") {
                    SecureField("API-ключ", text: $settings.apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("settings.apiKeyField")

                    TextField("Адрес сервиса", text: $settings.baseURLString)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("settings.baseURLField")

                    TextField("Модель", text: $settings.model)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("settings.modelField")
                } footer: {
                    Text("Подойдёт любой OpenAI-совместимый сервис с зрительной моделью: OpenAI, OpenRouter и др. По умолчанию — api.openai.com, модель gpt-4o-mini. Ключ хранится в Keychain устройства.")
                }
                .disabled(settings.useMockService)

                Section("Как это работает") {
                    Label("Сфотографируйте содержимое холодильника.", systemImage: "camera")
                    Label("Приложение распознает продукты на фото.", systemImage: "sparkle.magnifyingglass")
                    Label("Сравнит их с вашим списком покупок и покажет, что ещё нужно купить.", systemImage: "cart")
                }
                .foregroundStyle(.secondary)
            }
            .navigationTitle("Настройки")
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppSettings())
}
