import SwiftUI

/// Root canvas view hosting the main screen content with ambient glass backdrop.
struct RootContentView: View {
    var body: some View {
        ZStack {
            // Ambient backdrop for glass refraction
            ambientBackdrop
                .ignoresSafeArea()

            HomeView()
        }
        .preferredColorScheme(ThemeManager.shared.current.colorScheme)
    }

    /// Minimal ambient backdrop with subtle diffused gradients.
    private var ambientBackdrop: some View {
        ZStack {
            Color(.systemBackground)

            Circle()
                .fill(Color.blue.opacity(0.12))
                .blur(radius: 90)
                .frame(width: 320, height: 320)
                .offset(x: -120, y: -200)

            Circle()
                .fill(Color.indigo.opacity(0.10))
                .blur(radius: 100)
                .frame(width: 300, height: 300)
                .offset(x: 120, y: 350)
        }
    }
}
