import SwiftUI

/// Structured representation of a token in a transcript segment, separating words from punctuation.
public struct WordToken: Identifiable, Equatable, Sendable {
    public let id: Int
    public let maskIndex: Int?
    public let leadingPunctuation: String
    public let word: String
    public let trailingPunctuation: String

    public var isMaskable: Bool {
        maskIndex != nil && !word.isEmpty
    }

    public init(
        id: Int,
        maskIndex: Int?,
        leadingPunctuation: String = "",
        word: String,
        trailingPunctuation: String = ""
    ) {
        self.id = id
        self.maskIndex = maskIndex
        self.leadingPunctuation = leadingPunctuation
        self.word = word
        self.trailingPunctuation = trailingPunctuation
    }

    public static func parse(from text: String) -> [WordToken] {
        let normalized = text
            .replacingOccurrences(of: "—", with: " — ")
            .replacingOccurrences(of: "–", with: " – ")

        let rawTokens = normalized.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        var tokens: [WordToken] = []
        var nextMaskIndex = 0

        for (tokenIndex, raw) in rawTokens.enumerated() {
            let firstWordIndex = raw.firstIndex(where: { $0.isLetter || $0.isNumber })
            let lastWordIndex = raw.lastIndex(where: { $0.isLetter || $0.isNumber })

            if let first = firstWordIndex, let last = lastWordIndex {
                let leading = String(raw[..<first])
                let word = String(raw[first...last])
                let trailing = String(raw[raw.index(after: last)...])

                tokens.append(WordToken(
                    id: tokenIndex,
                    maskIndex: nextMaskIndex,
                    leadingPunctuation: leading,
                    word: word,
                    trailingPunctuation: trailing
                ))
                nextMaskIndex += 1
            } else {
                tokens.append(WordToken(
                    id: tokenIndex,
                    maskIndex: nil,
                    leadingPunctuation: "",
                    word: "",
                    trailingPunctuation: raw
                ))
            }
        }
        return tokens
    }

    public static func parse(words: [String]) -> [WordToken] {
        parse(from: words.joined(separator: " "))
    }
}

/// Renders words floating directly on the page with scratchable frosted glass capsules.
/// Punctuation marks are placed outside of the masked capsules, visible between words.
public struct WordScratchCardView: View {
    public let tokens: [WordToken]
    @Binding public var revealedIndices: Set<Int>
    public var onScratchWord: ((Int) -> Void)? = nil
    public var onSwipeLeft: (() -> Void)? = nil
    public var onSwipeRight: (() -> Void)? = nil

    @State private var wordFrames: [Int: CGRect] = [:]

    public init(
        tokens: [WordToken],
        revealedIndices: Binding<Set<Int>>,
        onScratchWord: ((Int) -> Void)? = nil,
        onSwipeLeft: (() -> Void)? = nil,
        onSwipeRight: (() -> Void)? = nil
    ) {
        self.tokens = tokens
        self._revealedIndices = revealedIndices
        self.onScratchWord = onScratchWord
        self.onSwipeLeft = onSwipeLeft
        self.onSwipeRight = onSwipeRight
    }

    public init(
        words: [String],
        revealedIndices: Binding<Set<Int>>,
        onScratchWord: ((Int) -> Void)? = nil,
        onSwipeLeft: (() -> Void)? = nil,
        onSwipeRight: (() -> Void)? = nil
    ) {
        self.tokens = WordToken.parse(words: words)
        self._revealedIndices = revealedIndices
        self.onScratchWord = onScratchWord
        self.onSwipeLeft = onSwipeLeft
        self.onSwipeRight = onSwipeRight
    }

    public var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    WordFlowLayout(horizontalSpacing: 8, verticalSpacing: 12) {
                        ForEach(tokens) { token in
                            tokenItemView(token: token)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 0)
                }
                .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .coordinateSpace(name: "WORD_STAGE_SPACE")
        .onPreferenceChange(WordFramePreferenceKey.self) { preferences in
            wordFrames = preferences
        }
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("WORD_STAGE_SPACE"))
                .onChanged { value in
                    handleTouch(at: value.location)
                }
                .onEnded { value in
                    let h = value.translation.width
                    let v = value.translation.height
                    // Detect predominantly horizontal swipe gesture
                    if abs(h) > 40 && abs(h) > abs(v) * 1.1 {
                        if h < 0 {
                            onSwipeLeft?()
                        } else {
                            onSwipeRight?()
                        }
                    }
                }
        )
    }

    @ViewBuilder
    private func tokenItemView(token: WordToken) -> some View {
        if let maskIdx = token.maskIndex, !token.word.isEmpty {
            HStack(alignment: .center, spacing: 3) {
                if !token.leadingPunctuation.isEmpty {
                    Text(token.leadingPunctuation)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .padding(.vertical, 7)
                }

                wordCapsuleView(word: token.word, maskIndex: maskIdx)

                if !token.trailingPunctuation.isEmpty {
                    Text(token.trailingPunctuation)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .padding(.vertical, 7)
                }
            }
        } else {
            // Standalone punctuation token (e.g. "—" or "...")
            Text(token.trailingPunctuation)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.88))
                .padding(.vertical, 7)
        }
    }

    private func wordCapsuleView(word: String, maskIndex: Int) -> some View {
        let isRevealed = revealedIndices.contains(maskIndex)

        return Text(word)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundStyle(isRevealed ? Color.white : Color.clear)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background {
                if isRevealed {
                    // Revealed: crystal liquid glass accent with optical edge
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.40), Color.white.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.8
                                )
                        }
                        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
                } else {
                    // Masked: frosted liquid mist capsule concealing word
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.38),
                                    Color.white.opacity(0.16)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .white.opacity(0.60), location: 0.0),
                                            .init(color: .white.opacity(0.25), location: 0.5),
                                            .init(color: .white.opacity(0.40), location: 1.0)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.0
                                )
                        }
                        .shadow(color: Color.black.opacity(0.20), radius: 8, x: 0, y: 3)
                }
            }
            .contentShape(Rectangle())
            .background(
                GeometryReader { wordGeo in
                    Color.clear
                        .preference(
                            key: WordFramePreferenceKey.self,
                            value: [maskIndex: wordGeo.frame(in: .named("WORD_STAGE_SPACE"))]
                        )
                }
            )
            .animation(DesignSystem.LiquidGlass.interactiveSpring, value: isRevealed)
    }

    private func handleTouch(at location: CGPoint) {
        for (index, frame) in wordFrames {
            // Expand hit area slightly for smooth fluid fingertip scrubbing
            let hitRect = frame.insetBy(dx: -4, dy: -4)
            if hitRect.contains(location) && !revealedIndices.contains(index) {
                revealedIndices.insert(index)
                onScratchWord?(index)
            }
        }
    }
}

private struct WordFramePreferenceKey: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
