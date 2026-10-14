import SwiftUI

@main
struct WiFiChangerApp: App {
    @StateObject private var store = Store()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if ProcessInfo.processInfo.arguments.contains("-gallery") {
                    WidgetGallery()
                } else {
                    ContentView()
                }
            }
            .environmentObject(store)
            .onOpenURL { url in
                Task { await store.handle(url) }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await store.refresh() }
            }
        }
    }
}
