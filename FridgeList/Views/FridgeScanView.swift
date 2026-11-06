import PhotosUI
import SwiftData
import SwiftUI

/// Главный экран: фото холодильника → распознавание → что уже есть / что купить.
struct FridgeScanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Query(sort: \ShoppingItem.addedAt) private var shoppingItems: [ShoppingItem]
    @Query(sort: \ScanRecord.date, order: .reverse) private var scans: [ScanRecord]

    @State private var photoItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var showCamera = false
    @State private var phase: Phase = .idle

    private enum Phase: Equatable {
        case idle
        case recognizing
        case done([String])
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    photoSection
                    actionSection
                    resultSection
                    historySection
                }
                .padding()
            }
            .navigationTitle("Мой холодильник")
            .sheet(isPresented: $showCamera) {
                CameraPicker { picked in
                    image = picked
                    phase = .idle
                }
                .ignoresSafeArea()
            }
            .onChange(of: photoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let picked = UIImage(data: data) {
                        image = picked
                        phase = .idle
                    }
                }
            }
        }
    }

    // MARK: - Фото

    @ViewBuilder
    private var photoSection: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 260)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .accessibilityLabel("Фото холодильника")
        } else {
            RoundedRectangle(cornerRadius: 16)
                .fill(.quaternary)
                .frame(height: 180)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                            .font(.largeTitle)
                        Text("Сфотографируйте продукты")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                }
        }

        HStack(spacing: 12) {
            Button {
                showCamera = true
            } label: {
                Label("Камера", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("scan.cameraButton")

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Галерея", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("scan.galleryButton")
        }
    }

    // MARK: - Запуск распознавания

    @ViewBuilder
    private var actionSection: some View {
        if image != nil {
            Button {
                Task { await recognize() }
            } label: {
                if phase == .recognizing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Что у меня есть?", systemImage: "sparkle.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(phase == .recognizing)
            .accessibilityIdentifier("scan.recognizeButton")

            if !settings.isConfigured {
                Label("Не настроен ИИ-сервис: добавьте API-ключ в настройках или включите демо-режим.",
                      systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Результат

    @ViewBuilder
    private var resultSection: some View {
        switch phase {
        case .failed(let message):
            GroupBox {
                Label(message, systemImage: "wifi.exclamationmark")
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .done(let recognized):
            if recognized.isEmpty {
                GroupBox {
                    Label("Продукты не распознаны. Попробуйте сфотографировать ближе и при хорошем свете.",
                          systemImage: "questionmark.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                resultContent(recognized: recognized)
            }

        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func resultContent(recognized: [String]) -> some View {
        let match = ProductMatcher.match(shoppingList: shoppingItems.map(\.name), recognized: recognized)

        if !shoppingItems.isEmpty {
            if !match.alreadyHave.isEmpty {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Уже есть дома — покупать не нужно", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.headline)
                        ForEach(match.alreadyHave, id: \.item) { pair in
                            HStack {
                                Text(pair.item)
                                    .strikethrough()
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button {
                                    removeFromShoppingList(named: pair.item)
                                } label: {
                                    Image(systemName: "cart.badge.minus")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Убрать «\(pair.item)» из списка покупок")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Ещё нужно купить", systemImage: "cart.fill")
                        .foregroundStyle(.orange)
                        .font(.headline)
                    if match.stillNeeded.isEmpty {
                        Text("Всё из списка уже есть в холодильнике 🎉")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(match.stillNeeded, id: \.self) { item in
                            Text("• \(item)")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("scan.stillNeededBox")
        }

        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label("Распознано на фото", systemImage: "refrigerator")
                    .font(.headline)
                Text(recognized.joined(separator: ", "))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - История

    @ViewBuilder
    private var historySection: some View {
        if !scans.isEmpty {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Прошлые сканирования", systemImage: "clock.arrow.circlepath")
                        .font(.headline)
                    ForEach(scans.prefix(3), id: \.date) { scan in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(scan.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(scan.productNames.joined(separator: ", "))
                                .font(.caption)
                                .lineLimit(2)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Логика

    private func recognize() async {
        guard let image, let data = image.preparedForVision() else { return }
        phase = .recognizing
        do {
            let service: VisionService = settings.useMockService
                ? MockVisionService()
                : OpenAIVisionService(settings: settings)
            let products = try await service.recognizeProducts(in: data)
            phase = .done(products)
            modelContext.insert(ScanRecord(productNames: products))
        } catch is CancellationError {
            phase = .idle
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func removeFromShoppingList(named name: String) {
        for item in shoppingItems where ProductMatcher.normalize(item.name) == ProductMatcher.normalize(name) {
            modelContext.delete(item)
        }
    }
}

#Preview {
    FridgeScanView()
        .environment(AppSettings())
        .modelContainer(for: [ShoppingItem.self, ScanRecord.self], inMemory: true)
}
