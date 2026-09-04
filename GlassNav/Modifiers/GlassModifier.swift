import SwiftUI

/// A reusable ViewModifier that renders modern frosted glass with optical refraction highlights and ambient shadows.
struct GlassBackgroundModifier<S: InsettableShape>: ViewModifier {
    var shape: S
    var material: Material = .ultraThinMaterial
    var strokeWidth: CGFloat = 1.0
    var shadowRadius: CGFloat = 20.0

    func body(content: Content) -> some View {
        content
            .background {
                shape
                    .fill(material)
                    .overlay {
                        shape
                            .strokeBorder(specularGradient, lineWidth: strokeWidth)
                    }
                    .shadow(color: .black.opacity(0.12), radius: shadowRadius, x: 0, y: shadowRadius * 0.5)
                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
    }

    /// Optical specular highlight gradient simulating light refraction along glass edges.
    private var specularGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(0.55), location: 0.0),
                .init(color: .white.opacity(0.15), location: 0.35),
                .init(color: .clear, location: 0.65),
                .init(color: .white.opacity(0.20), location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension View {
    /// Applies a modern frosted glass background with refractive edge stroke and ambient shadows.
    func glassBackground<S: InsettableShape>(
        shape: S,
        material: Material = .ultraThinMaterial,
        strokeWidth: CGFloat = 1.0,
        shadowRadius: CGFloat = 20.0
    ) -> some View {
        modifier(
            GlassBackgroundModifier(
                shape: shape,
                material: material,
                strokeWidth: strokeWidth,
                shadowRadius: shadowRadius
            )
        )
    }

    /// Convenience modifier applying a Capsule glass background.
    func glassCapsule(
        material: Material = .ultraThinMaterial,
        strokeWidth: CGFloat = 1.0,
        shadowRadius: CGFloat = 20.0
    ) -> some View {
        glassBackground(
            shape: Capsule(),
            material: material,
            strokeWidth: strokeWidth,
            shadowRadius: shadowRadius
        )
    }

    /// Convenience modifier applying a Circle glass background.
    func glassCircle(
        material: Material = .ultraThinMaterial,
        strokeWidth: CGFloat = 1.0,
        shadowRadius: CGFloat = 16.0
    ) -> some View {
        glassBackground(
            shape: Circle(),
            material: material,
            strokeWidth: strokeWidth,
            shadowRadius: shadowRadius
        )
    }
}
