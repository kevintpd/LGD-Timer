import SwiftData
import SwiftUI

@main
struct LGDTimeriPhoneApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: TimerRecord.self)
    }
}
