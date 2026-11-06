import SwiftData
import SwiftUI

@main
struct FridgeListApp: App {
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
        }
        .modelContainer(for: [ShoppingItem.self, ScanRecord.self])
    }
}
