import SwiftUI

@main
struct GlassNavApp: App {
    private let container: any AppContainerProtocol = ProductionContainer()

    var body: some Scene {
        WindowGroup {
            RootContentView()
                .environment(\.appContainer, container)
        }
    }
}
