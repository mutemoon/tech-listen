import SwiftUI

/// Single interactive tab item inside the glass navigation bar.
struct GlassTabItem: View {
    let item: TabItem
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? item.selectedIcon : item.icon)
                    .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                    .contentTransition(.symbolEffect(.replace))
                    .scaleEffect(isSelected ? 1.05 : 1.0)

                if isSelected {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.85, anchor: .leading)),
                            removal: .opacity
                        ))
                }
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .padding(.vertical, 10)
            .padding(.horizontal, isSelected ? 16 : 14)
            .background {
                if isSelected {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.6), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.8
                                )
                        }
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
                        .matchedGeometryEffect(id: "ACTIVE_TAB_INDICATOR", in: namespace)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
