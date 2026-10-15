import SwiftUI

@main
struct EightOhEightApp: App {
    @State private var model = MachineModel()

    var body: some Scene {
        WindowGroup {
            MachineRoot(model: model)
                .preferredColorScheme(.dark)
                .statusBarHidden()
        }
    }
}
