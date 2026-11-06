import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            FridgeScanView()
                .tabItem {
                    Label("Холодильник", systemImage: "camera.viewfinder")
                }

            ShoppingListView()
                .tabItem {
                    Label("Покупки", systemImage: "cart")
                }

            SettingsView()
                .tabItem {
                    Label("Настройки", systemImage: "gearshape")
                }
        }
        .tint(.green)
    }
}

#Preview {
    ContentView()
        .environment(AppSettings())
        .modelContainer(for: [ShoppingItem.self, ScanRecord.self], inMemory: true)
}
