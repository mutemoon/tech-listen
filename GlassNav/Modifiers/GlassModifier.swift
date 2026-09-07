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
            .contentShape(shape)
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

// MARK: - iOS 26 Native Liquid Glass Container Wrapper

@available(iOS 26.0, *)
private struct NativeGlassContainer<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        GlassEffectContainer(spacing: spacing) {
            content()
        }
    }
}

/// Adaptive glass container that activates Apple's Liquid Glass morphing and GPU batching on iOS 26+,
/// while falling back to a standard SwiftUI container on earlier versions.
public struct AdaptiveGlassContainer<Content: View>: View {
    public var spacing: CGFloat
    @ViewBuilder public var content: () -> Content

    public init(spacing: CGFloat = 12.0, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        if #available(iOS 26.0, *) {
            NativeGlassContainer(spacing: spacing, content: content)
        } else {
            content()
        }
    }
}

// MARK: - Button Style Compatibility

public struct BouncyGlassButtonStyle: ButtonStyle {
    public var prominent: Bool = false

    public init(prominent: Bool = false) {
        self.prominent = prominent
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.20, dampingFraction: 0.70), value: configuration.isPressed)
    }
}

// MARK: - View Extensions

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

    // MARK: - Liquid Glass (iOS 26+) First-Class Modifiers

    /// Applies Apple's iOS 26 Liquid Glass effect to a Capsule, reacting to touch when interactive.
    @ViewBuilder
    func liquidGlassCapsule(
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, *) {
            if let tint = tint {
                if interactive {
                    self.glassEffect(.regular.tint(tint).interactive(), in: .capsule)
                        .contentShape(Capsule())
                } else {
                    self.glassEffect(.regular.tint(tint), in: .capsule)
                        .contentShape(Capsule())
                }
            } else {
                if interactive {
                    self.glassEffect(.regular.interactive(), in: .capsule)
                        .contentShape(Capsule())
                } else {
                    self.glassEffect(in: .capsule)
                        .contentShape(Capsule())
                }
            }
        } else {
            self.glassCapsule(shadowRadius: interactive ? 18.0 : 12.0)
                .contentShape(Capsule())
        }
    }

    /// Applies Apple's iOS 26 Liquid Glass effect to a Circle, reacting to touch when interactive.
    @ViewBuilder
    func liquidGlassCircle(
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, *) {
            if let tint = tint {
                if interactive {
                    self.glassEffect(.regular.tint(tint).interactive(), in: .circle)
                        .contentShape(Circle())
                } else {
                    self.glassEffect(.regular.tint(tint), in: .circle)
                        .contentShape(Circle())
                }
            } else {
                if interactive {
                    self.glassEffect(.regular.interactive(), in: .circle)
                        .contentShape(Circle())
                } else {
                    self.glassEffect(in: .circle)
                        .contentShape(Circle())
                }
            }
        } else {
            self.glassCircle(shadowRadius: interactive ? 16.0 : 10.0)
                .contentShape(Circle())
        }
    }

    /// Applies Apple's iOS 26 Liquid Glass effect to a continuous RoundedRectangle card.
    @ViewBuilder
    func liquidGlassCard(
        cornerRadius: CGFloat = 22.0,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        let cardShape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            if let tint = tint {
                if interactive {
                    self.glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: cornerRadius))
                        .contentShape(cardShape)
                } else {
                    self.glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
                        .contentShape(cardShape)
                }
            } else {
                if interactive {
                    self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
                        .contentShape(cardShape)
                } else {
                    self.glassEffect(in: .rect(cornerRadius: cornerRadius))
                        .contentShape(cardShape)
                }
            }
        } else {
            self.glassBackground(
                shape: cardShape,
                shadowRadius: interactive ? 22.0 : 16.0
            )
            .contentShape(cardShape)
        }
    }

    /// Associates an element with a morph identifier for smooth transition between Liquid Glass geometries.
    @ViewBuilder
    func liquidGlassMorphID(_ id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffectID(id, in: namespace)
        } else {
            self.matchedGeometryEffect(id: id, in: namespace)
        }
    }
}
