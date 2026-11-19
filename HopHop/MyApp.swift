import SwiftUI

@main
struct HopHopApp: App {
    @State private var store = ApplicationStore()

    init() {
        HH.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 800)
    }
}
