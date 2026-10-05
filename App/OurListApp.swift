import SwiftUI

@main
struct OurListApp: App {
    @MainActor
    init() {
        try? FirebaseList.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
