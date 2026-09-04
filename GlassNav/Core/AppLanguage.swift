import SwiftUI

public enum Language: String, CaseIterable, Identifiable, Sendable {
    case chinese = "zh"
    case english = "en"

    public var id: String { rawValue }

    public var displayTitle: String {
        switch self {
        case .chinese: "中文"
        case .english: "English"
        }
    }

    public func string(_ key: Key) -> String {
        let isZh = self == .chinese
        switch key {
        case .brandName:
            return isZh ? "科听" : "Listen Tech"
        case .tagline:
            return isZh ? "前沿科技声音与文稿" : "Curated Tech Audio and Text"
        case .tabHome:
            return isZh ? "精选" : "Feed"
        case .tabSettings:
            return isZh ? "设置" : "Settings"
        case .actionDownload:
            return isZh ? "下载" : "Download"
        case .actionPlay:
            return isZh ? "播放" : "Play"
        case .actionPause:
            return isZh ? "暂停" : "Pause"
        case .statusBuffering:
            return isZh ? "缓冲中" : "Buffering"
        case .actionDelete:
            return isZh ? "删除" : "Delete"
        case .actionCancel:
            return isZh ? "取消" : "Cancel"
        case .actionClear:
            return isZh ? "清空" : "Clear"
        case .confirmDeleteTitle:
            return isZh ? "确认删除这期内容" : "Delete this episode"
        case .confirmClearCacheTitle:
            return isZh ? "确认清空所有缓存" : "Clear all cache"
        case .filterAll:
            return isZh ? "全部" : "All"
        case .sentencesUnit:
            return isZh ? "句" : "lines"
        case .cacheUsedRow:
            return isZh ? "已用缓存" : "Cache Used"
            
        // Settings Section Keys
        case .settingsAppearanceSection:
            return isZh ? "外观与语言" : "Appearance and Language"
        case .settingsStorageSection:
            return isZh ? "存储与缓存" : "Storage and Cache"
        case .settingsAdvancedSection:
            return isZh ? "高级选项" : "Advanced Parameters"
        case .settingsLanguageRow:
            return isZh ? "显示语言" : "Language"
        case .settingsThemeRow:
            return isZh ? "主题模式" : "Theme"
        case .settingsClearCacheRow:
            return isZh ? "清空缓存" : "Clear Cache"
        case .settingsPageSizeRow:
            return isZh ? "单次载入篇数" : "Batch Size"
        case .settingsStrokeWidthRow:
            return isZh ? "边框微光宽度" : "Border Width"
        case .settingsShadowRadiusRow:
            return isZh ? "投影扩散深度" : "Shadow Depth"
        case .settingsAnimationDurationRow:
            return isZh ? "动效平滑时间" : "Animation Duration"
        case .settingsHapticRow:
            return isZh ? "触觉微交互" : "Haptics"
        case .settingsResetAction:
            return isZh ? "恢复初始参数" : "Reset Defaults"
        case .scrollToTop:
            return isZh ? "回到顶部" : "Back to Top"
        case .themeSystem:
            return isZh ? "跟随系统" : "System"
        case .themeLight:
            return isZh ? "浅色" : "Light"
        case .themeDark:
            return isZh ? "暗色" : "Dark"
        case .refreshUpToDate:
            return isZh ? "已是最新内容" : "Already up to date"
        case .refreshFailed:
            return isZh ? "刷新失败，请检查网络连接" : "Refresh failed, check connection"
        }
    }

    /// Formats audio duration according to the current language.
    public func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        guard totalSeconds > 0 else { return "--" }
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let isZh = self == .chinese

        if hours > 0 {
            if isZh {
                return minutes > 0 ? "\(hours)小时\(minutes)分" : "\(hours)小时"
            } else {
                return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
            }
        } else {
            let mins = max(1, minutes)
            if isZh {
                return "\(mins)分钟"
            } else {
                return "\(mins)m"
            }
        }
    }

    /// Formats refresh success message indicating either new episode count or up to date.
    public func formatRefreshSuccess(newCount: Int) -> String {
        let isZh = self == .chinese
        if newCount > 0 {
            return isZh ? "已更新 \(newCount) 条新内容" : "Updated \(newCount) new \(newCount == 1 ? "episode" : "episodes")"
        } else {
            return string(.refreshUpToDate)
        }
    }

    /// Formats real-time download speed (e.g. "2.4 MB/s" or "850 KB/s").
    public func formatDownloadSpeed(_ bytesPerSec: Double) -> String {
        guard bytesPerSec > 0 else { return "0 KB/s" }
        if bytesPerSec >= 1024 * 1024 {
            let mb = bytesPerSec / (1024 * 1024)
            return String(format: "%.1f MB/s", mb)
        } else {
            let kb = bytesPerSec / 1024
            return String(format: "%.0f KB/s", kb)
        }
    }

    /// Formats remaining download size (e.g. "剩余 45.2 MB" or "45.2 MB left").
    public func formatRemainingSize(_ remainingBytes: Int64) -> String {
        let isZh = self == .chinese
        guard remainingBytes > 0 else {
            return isZh ? "剩余 0 MB" : "0 MB left"
        }
        let sizeStr: String
        if remainingBytes >= 1024 * 1024 * 1024 {
            let gb = Double(remainingBytes) / Double(1024 * 1024 * 1024)
            sizeStr = String(format: "%.2f GB", gb)
        } else if remainingBytes >= 1024 * 1024 {
            let mb = Double(remainingBytes) / Double(1024 * 1024)
            sizeStr = String(format: "%.1f MB", mb)
        } else {
            let kb = Double(remainingBytes) / 1024.0
            sizeStr = String(format: "%.0f KB", kb)
        }
        return isZh ? "剩余 \(sizeStr)" : "\(sizeStr) left"
    }

    /// Formats estimated time remaining (e.g. "预计 25秒", "预计 1分10秒", "计算中...").
    public func formatEstimatedTimeRemaining(_ seconds: TimeInterval?) -> String {
        let isZh = self == .chinese
        guard let secs = seconds, secs > 0, !secs.isInfinite, !secs.isNaN else {
            return isZh ? "计算中..." : "Calculating..."
        }
        let totalSecs = Int(secs)
        let hours = totalSecs / 3600
        let minutes = (totalSecs % 3600) / 60
        let s = totalSecs % 60
        let timeStr: String
        if hours > 0 {
            timeStr = isZh ? "\(hours)小时\(minutes)分" : "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            timeStr = isZh ? "\(minutes)分\(s)秒" : "\(minutes)m \(s)s"
        } else {
            timeStr = isZh ? "\(max(1, s))秒" : "\(max(1, s))s"
        }
        return isZh ? "预计 \(timeStr)" : "~\(timeStr) left"
    }

    public enum Key: Sendable {
        case brandName
        case tagline
        case tabHome
        case tabSettings
        case actionDownload
        case actionPlay
        case actionPause
        case statusBuffering
        case actionDelete
        case actionCancel
        case actionClear
        case confirmDeleteTitle
        case confirmClearCacheTitle
        case filterAll
        case sentencesUnit
        case cacheUsedRow
        case settingsAppearanceSection
        case settingsStorageSection
        case settingsAdvancedSection
        case settingsLanguageRow
        case settingsThemeRow
        case settingsClearCacheRow
        case settingsPageSizeRow
        case settingsStrokeWidthRow
        case settingsShadowRadiusRow
        case settingsAnimationDurationRow
        case settingsHapticRow
        case settingsResetAction
        case scrollToTop
        case themeSystem
        case themeLight
        case themeDark
        case refreshUpToDate
        case refreshFailed
    }
}

@Observable
@MainActor
public final class LanguageManager {
    public static let shared = LanguageManager()
    public var current: Language = .chinese

    public func toggle() {
        current = current == .chinese ? .english : .chinese
    }

    public func string(_ key: Language.Key) -> String {
        return current.string(key)
    }

    public func formatDuration(_ seconds: TimeInterval) -> String {
        return current.formatDuration(seconds)
    }

    public func formatRefreshSuccess(newCount: Int) -> String {
        return current.formatRefreshSuccess(newCount: newCount)
    }

    public func formatDownloadSpeed(_ bytesPerSec: Double) -> String {
        return current.formatDownloadSpeed(bytesPerSec)
    }

    public func formatRemainingSize(_ remainingBytes: Int64) -> String {
        return current.formatRemainingSize(remainingBytes)
    }

    public func formatEstimatedTimeRemaining(_ seconds: TimeInterval?) -> String {
        return current.formatEstimatedTimeRemaining(seconds)
    }
}

