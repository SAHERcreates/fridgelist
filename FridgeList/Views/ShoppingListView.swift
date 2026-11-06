import SwiftData
import SwiftUI

/// Ручной список покупок: что планирую купить.
struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingItem.addedAt) private var items: [ShoppingItem]

    @State private var newItemName = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Например, молоко", text: $newItemName)
                            .focused($fieldFocused)
                            .submitLabel(.done)
                            .onSubmit(addItem)
                            .accessibilityIdentifier("list.newItemField")
                        Button {
                            addItem()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .disabled(newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("list.addButton")
                    }
                }

                Section {
                    if items.isEmpty {
                        Text("Список пуст. Добавьте продукты, которые обычно покупаете, — после сканирования холодильника приложение покажет, чего из них не хватает.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(items) { item in
                            Text(item.name)
                        }
                        .onDelete(perform: delete)
                    }
                } header: {
                    if !items.isEmpty {
                        Text("Нужно купить: \(items.count)")
                    }
                }
            }
            .navigationTitle("Список покупок")
        }
    }

    private func addItem() {
        let name = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let isDuplicate = items.contains {
            ProductMatcher.normalize($0.name) == ProductMatcher.normalize(name)
        }
        if !isDuplicate {
            modelContext.insert(ShoppingItem(name: name))
        }
        newItemName = ""
        fieldFocused = true
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
}

#Preview {
    ShoppingListView()
        .modelContainer(for: ShoppingItem.self, inMemory: true)
}
