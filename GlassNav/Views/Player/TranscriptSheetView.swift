import SwiftUI

/// Full transcript drawer displaying time-aligned sentence segments.
public struct TranscriptSheetView: View {
    public let segments: [TranscriptSegment]
    public let currentSegmentIndex: Int
    public var onSelectSegment: (TranscriptSegment, Int) -> Void
    @Environment(\.dismiss) private var dismiss

    public init(
        segments: [TranscriptSegment],
        currentSegmentIndex: Int,
        onSelectSegment: @escaping (TranscriptSegment, Int) -> Void
    ) {
        self.segments = segments
        self.currentSegmentIndex = currentSegmentIndex
        self.onSelectSegment = onSelectSegment
    }

    public var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                            segmentRow(segment: segment, index: index)
                                .id(index)
                                .onTapGesture {
                                    onSelectSegment(segment, index)
                                    dismiss()
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
                .onAppear {
                    if currentSegmentIndex >= 0 && currentSegmentIndex < segments.count {
                        scrollProxy.scrollTo(currentSegmentIndex, anchor: .center)
                    }
                }
            }
            .navigationTitle("全文")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func segmentRow(segment: TranscriptSegment, index: Int) -> some View {
        let isCurrent = index == currentSegmentIndex

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(index + 1) / \(segments.count)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(isCurrent ? Color.blue : Color.secondary)

                Spacer()

                Text(segment.timestamp)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if !segment.speaker.isEmpty {
                Text(segment.speaker)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text(segment.text)
                .font(.system(size: 15, weight: isCurrent ? .semibold : .regular))
                .foregroundStyle(.primary)
                .lineSpacing(4)
        }
        .padding(16)
        .liquidGlassCard(
            cornerRadius: 18,
            tint: isCurrent ? Color.blue.opacity(0.22) : nil,
            interactive: true
        )
        .shadow(color: isCurrent ? Color.blue.opacity(0.22) : Color.black.opacity(0.08), radius: isCurrent ? 8 : 4, x: 0, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
