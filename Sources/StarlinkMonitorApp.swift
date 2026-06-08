import SwiftUI
import SwiftData

@main
struct StarlinkMonitorApp: App {
    @State private var showSplash = true
    @StateObject private var updaterViewModel = UpdaterViewModel()
    @StateObject private var monitor = TelemetryMonitor()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TelemetrySnapshot.self, OutageEvent.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                } else {
                    ContentView(monitor: monitor)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 1.0), value: showSplash)
            .onAppear {
                monitor.modelContainer = sharedModelContainer
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showSplash = false
                }
            }
        }
        .modelContainer(for: [TelemetrySnapshot.self, OutageEvent.self])
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    updaterViewModel.checkForUpdates()
                }
                .disabled(!updaterViewModel.canCheckForUpdates)
            }
        }
        
        MenuBarExtra("Starlink Monitor", systemImage: "antenna.radiowaves.left.and.right") {
            MenuBarView(monitor: monitor)
        }
        .menuBarExtraStyle(.window)
    }
}
