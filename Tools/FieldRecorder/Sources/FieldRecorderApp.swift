import SwiftUI

@main
struct FieldRecorderApp: App {
    @State private var recorder = RecorderController()

    var body: some Scene {
        WindowGroup {
            ContentView(recorder: recorder)
        }
    }
}
