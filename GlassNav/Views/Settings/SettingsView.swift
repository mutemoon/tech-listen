import SwiftUI

/// Settings view grouped by category with left-description right-control layout.
/// Features cache size display with confirmation, and expandable advanced options.
struct SettingsView: View {
    @Environment(\.appContainer) private var container
    @State private var viewModel: SettingsViewModel?
    @State private var showClearCacheConfirmation: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            PageHeaderView(title: LanguageManager.shared.string(.tabSettings)) {
                Button {
                    container.feedbackService.triggerTap()
                    viewModel?.resetDefaults()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .liquidGlassCircle(interactive: true)
                        .shadow(color: Color.black.opacity(0.14), radius: 6, x: 0, y: 2)
                        .contentShape(Circle())
                }
                .buttonStyle(BouncyGlassButtonStyle())
                .accessibilityLabel(LanguageManager.shared.string(.settingsResetAction))
            }

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 20) {
                    if let vm = viewModel {
                    // Group 1: Appearance and Language
                    sectionCard(title: LanguageManager.shared.string(.settingsAppearanceSection)) {
                        VStack(spacing: 16) {
                            // Row 1: Language
                            HStack {
                                Text(LanguageManager.shared.string(.settingsLanguageRow))
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.primary)

                                Spacer()

                                Picker("", selection: Binding(
                                    get: { vm.language },
                                    set: { vm.language = $0 }
                                )) {
                                    Text(Language.chinese.displayTitle).tag(Language.chinese)
                                    Text(Language.english.displayTitle).tag(Language.english)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 140)
                            }

                            Divider().opacity(0.15)

                            // Row 2: Haptic feedback
                            HStack {
                                Text(LanguageManager.shared.string(.settingsHapticRow))
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.primary)

                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { vm.hapticEnabled },
                                    set: { vm.hapticEnabled = $0 }
                                ))
                                .labelsHidden()
                            }
                        }
                    }

                    // Group 2: Storage and Cache
                    sectionCard(title: LanguageManager.shared.string(.settingsStorageSection)) {
                        HStack {
                            Text(LanguageManager.shared.string(.cacheUsedRow))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.primary)

                            Spacer()

                            HStack(spacing: 12) {
                                Text(vm.cacheSizeDisplay)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)

                                Button(action: {
                                    showClearCacheConfirmation = true
                                }) {
                                    Text(LanguageManager.shared.string(.actionClear))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .liquidGlassCapsule(interactive: true)
                                        .contentShape(Capsule())
                                }
                                .buttonStyle(BouncyGlassButtonStyle())
                                .confirmationDialog(
                                    LanguageManager.shared.string(.confirmClearCacheTitle),
                                    isPresented: $showClearCacheConfirmation,
                                    titleVisibility: .visible
                                ) {
                                    Button(LanguageManager.shared.string(.actionClear), role: .destructive) {
                                        vm.clearCache()
                                    }
                                    Button(LanguageManager.shared.string(.actionCancel), role: .cancel) {}
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .ignoresSafeArea(edges: .bottom)
    }
        .background {
            ZStack {
                Color.black

                Circle()
                    .fill(Color(red: 0.12, green: 0.38, blue: 0.92).opacity(0.12))
                    .blur(radius: 90)
                    .frame(width: 300, height: 300)
                    .offset(x: -90, y: -180)

                Circle()
                    .fill(Color(red: 0.35, green: 0.18, blue: 0.80).opacity(0.10))
                    .blur(radius: 95)
                    .frame(width: 280, height: 280)
                    .offset(x: 100, y: 220)
            }
            .ignoresSafeArea()
        }
        .task {
            if viewModel == nil {
                viewModel = SettingsViewModel(
                    configService: container.configurationService,
                    feedbackService: container.feedbackService,
                    cacheService: container.cacheService,
                    episodeRepository: container.episodeRepository,
                    downloadManager: container.downloadManager
                )
            }
            viewModel?.refreshCacheSize()
        }
        .onAppear {
            viewModel?.refreshCacheSize()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("didChangeCacheStorage"))) { _ in
            viewModel?.refreshCacheSize()
        }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(18)
        .liquidGlassCard(cornerRadius: 22)
    }
}
