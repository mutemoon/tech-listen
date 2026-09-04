import SwiftUI

/// Settings view grouped by category with left-description right-control layout.
/// Features cache size display with confirmation, and expandable advanced options.
struct SettingsView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SettingsViewModel?
    @State private var showClearCacheConfirmation: Bool = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 20) {
                headerView

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
                                    get: { LanguageManager.shared.current },
                                    set: { newLang in
                                        LanguageManager.shared.current = newLang
                                        container.feedbackService.triggerTap()
                                    }
                                )) {
                                    Text(Language.chinese.displayTitle).tag(Language.chinese)
                                    Text(Language.english.displayTitle).tag(Language.english)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 140)
                            }

                            Divider().opacity(0.15)

                            // Row 2: Theme
                            HStack {
                                Text(LanguageManager.shared.string(.settingsThemeRow))
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.primary)

                                Spacer()

                                Picker("", selection: Binding(
                                    get: { ThemeManager.shared.current },
                                    set: { newTheme in
                                        ThemeManager.shared.current = newTheme
                                        container.feedbackService.triggerTap()
                                    }
                                )) {
                                    Text(LanguageManager.shared.string(.themeSystem)).tag(AppTheme.system)
                                    Text(LanguageManager.shared.string(.themeLight)).tag(AppTheme.light)
                                    Text(LanguageManager.shared.string(.themeDark)).tag(AppTheme.dark)
                                }
                                .pickerStyle(.menu)
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
                                        .background(
                                            Capsule()
                                                .fill(.ultraThinMaterial)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
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

                    // Group 3: Expandable Advanced Options
                    sectionCard(title: LanguageManager.shared.string(.settingsAdvancedSection)) {
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { vm.isAdvancedExpanded },
                                set: { vm.isAdvancedExpanded = $0 }
                            )
                        ) {
                            VStack(spacing: 16) {
                                Divider().opacity(0.15).padding(.top, 8)

                                // Parameter 1: Batch size
                                HStack {
                                    Text(LanguageManager.shared.string(.settingsPageSizeRow))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    Stepper(value: Binding(
                                        get: { vm.pageSize },
                                        set: { vm.pageSize = $0 }
                                    ), in: 1...8) {
                                        Text("\(vm.pageSize)")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Divider().opacity(0.15)

                                // Parameter 2: Stroke width
                                HStack {
                                    Text(LanguageManager.shared.string(.settingsStrokeWidthRow))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    Slider(value: Binding(
                                        get: { vm.glassStrokeWidth },
                                        set: { vm.glassStrokeWidth = $0 }
                                    ), in: 0.5...2.5)
                                    .frame(width: 120)
                                }

                                Divider().opacity(0.15)

                                // Parameter 3: Shadow radius
                                HStack {
                                    Text(LanguageManager.shared.string(.settingsShadowRadiusRow))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    Slider(value: Binding(
                                        get: { vm.glassShadowRadius },
                                        set: { vm.glassShadowRadius = $0 }
                                    ), in: 6.0...28.0)
                                    .frame(width: 120)
                                }

                                Divider().opacity(0.15)

                                // Parameter 4: Animation duration
                                HStack {
                                    Text(LanguageManager.shared.string(.settingsAnimationDurationRow))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    Slider(value: Binding(
                                        get: { vm.animationDuration },
                                        set: { vm.animationDuration = $0 }
                                    ), in: 0.15...0.65)
                                    .frame(width: 120)
                                }

                                Divider().opacity(0.15)

                                // Parameter 5: Haptic feedback
                                HStack {
                                    Text(LanguageManager.shared.string(.settingsHapticRow))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    Toggle("", isOn: Binding(
                                        get: { vm.hapticEnabled },
                                        set: { vm.hapticEnabled = $0 }
                                    ))
                                    .labelsHidden()
                                }

                                Divider().opacity(0.15)

                                // Reset to defaults
                                HStack {
                                    Text(LanguageManager.shared.string(.settingsResetAction))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.secondary)

                                    Spacer()

                                    Button(action: {
                                        vm.resetDefaults()
                                    }) {
                                        Text(LanguageManager.shared.string(.settingsResetAction))
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(.ultraThinMaterial)
                                            )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        } label: {
                            HStack {
                                Text(LanguageManager.shared.string(.settingsAdvancedSection))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background {
            ZStack {
                Color(.systemBackground)

                Circle()
                    .fill(Color.blue.opacity(0.08))
                    .blur(radius: 80)
                    .frame(width: 280, height: 280)
                    .offset(x: -90, y: -180)

                Circle()
                    .fill(Color.indigo.opacity(0.07))
                    .blur(radius: 90)
                    .frame(width: 260, height: 260)
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

    private var headerView: some View {
        HStack(alignment: .center) {
            Text(LanguageManager.shared.string(.tabSettings))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                container.feedbackService.triggerTap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.8)
                    }
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(LanguageManager.shared.string(.actionCancel))
        }
        .padding(.vertical, 8)
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(18)
        .glassBackground(
            shape: RoundedRectangle(cornerRadius: 22, style: .continuous),
            material: .ultraThinMaterial,
            strokeWidth: container.configurationService.glassStrokeWidth,
            shadowRadius: container.configurationService.glassShadowRadius
        )
    }
}
