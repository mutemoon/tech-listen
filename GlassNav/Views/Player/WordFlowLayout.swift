import SwiftUI

/// Custom flow layout that wraps word capsules across lines and centers each line horizontally.
public struct WordFlowLayout: Layout {
    public var horizontalSpacing: CGFloat
    public var verticalSpacing: CGFloat

    public init(horizontalSpacing: CGFloat = 8, verticalSpacing: CGFloat = 12) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    public struct CacheData {
        var lines: [Line] = []
        var totalSize: CGSize = .zero
    }

    public struct Line {
        var range: Range<Int>
        var size: CGSize
    }

    public func makeCache(subviews: Subviews) -> CacheData {
        CacheData()
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) -> CGSize {
        let maxWidth = proposal.width ?? 320
        calculateLayout(maxWidth: maxWidth, subviews: subviews, cache: &cache)
        return cache.totalSize
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) {
        calculateLayout(maxWidth: bounds.width, subviews: subviews, cache: &cache)

        var currentY = bounds.minY
        for line in cache.lines {
            let lineXOffset = bounds.minX + max(0, (bounds.width - line.size.width) / 2)
            var currentX = lineXOffset

            for index in line.range {
                let subview = subviews[index]
                let subviewSize = subview.sizeThatFits(.unspecified)
                let subviewY = currentY + (line.size.height - subviewSize.height) / 2
                subview.place(
                    at: CGPoint(x: currentX, y: subviewY),
                    proposal: ProposedViewSize(subviewSize)
                )
                currentX += subviewSize.width + horizontalSpacing
            }

            currentY += line.size.height + verticalSpacing
        }
    }

    private func calculateLayout(maxWidth: CGFloat, subviews: Subviews, cache: inout CacheData) {
        var lines: [Line] = []
        var currentLineStartIndex = 0
        var currentLineWidth: CGFloat = 0
        var currentLineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxLineWidth: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let neededWidth = currentLineWidth == 0 ? size.width : (currentLineWidth + horizontalSpacing + size.width)

            if neededWidth > maxWidth && currentLineWidth > 0 {
                // Wrap to next line
                lines.append(Line(
                    range: currentLineStartIndex..<index,
                    size: CGSize(width: currentLineWidth, height: currentLineHeight)
                ))
                maxLineWidth = max(maxLineWidth, currentLineWidth)
                totalHeight += currentLineHeight + verticalSpacing

                currentLineStartIndex = index
                currentLineWidth = size.width
                currentLineHeight = size.height
            } else {
                currentLineWidth = neededWidth
                currentLineHeight = max(currentLineHeight, size.height)
            }
        }

        if currentLineStartIndex < subviews.count {
            lines.append(Line(
                range: currentLineStartIndex..<subviews.count,
                size: CGSize(width: currentLineWidth, height: currentLineHeight)
            ))
            maxLineWidth = max(maxLineWidth, currentLineWidth)
            totalHeight += currentLineHeight
        }

        cache.lines = lines
        cache.totalSize = CGSize(width: maxLineWidth, height: totalHeight)
    }
}
