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
        case .tabSettings:
            return isZh ? "设置" : "Settings"
        case .actionDownload:
            return isZh ? "下载" : "Download"
        case .actionCancel:
            return isZh ? "取消" : "Cancel"
        case .actionClear:
            return isZh ? "清空" : "Clear"
        case .confirmClearCacheTitle:
            return isZh ? "清空所有缓存" : "Clear all cache"
        case .sentencesUnit:
            return isZh ? "句" : "lines"
        case .cacheUsedRow:
            return isZh ? "缓存" : "Cache"
        case .statusDownloaded:
            return isZh ? "已下载" : "Downloaded"
        case .settingsAppearanceSection:
            return isZh ? "通用" : "General"
        case .settingsStorageSection:
            return isZh ? "存储" : "Storage"
        case .settingsLanguageRow:
            return isZh ? "语言" : "Language"
        case .settingsHapticRow:
            return isZh ? "触感反馈" : "Haptic Feedback"
        case .settingsResetAction:
            return isZh ? "恢复默认" : "Reset Defaults"
        case .scrollToTop:
            return isZh ? "回到顶部" : "Back to Top"
        case .refreshUpToDate:
            return isZh ? "已是最新" : "Already up to date"
        case .refreshFailed:
            return isZh ? "刷新失败" : "Refresh failed"
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
            return "--"
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
        case tabSettings
        case actionDownload
        case actionCancel
        case actionClear
        case confirmClearCacheTitle
        case sentencesUnit
        case cacheUsedRow
        case statusDownloaded
        case settingsAppearanceSection
        case settingsStorageSection
        case settingsLanguageRow
        case settingsHapticRow
        case settingsResetAction
        case scrollToTop
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

