public struct CaptionLine: Equatable, Sendable, Identifiable {
    public let id: Int
    public let committed: String
    public let tentative: String

    public init(id: Int, committed: String, tentative: String) {
        self.id = id
        self.committed = committed
        self.tentative = tentative
    }

    public var text: String { committed + tentative }
}

public struct CaptionWindow: Equatable, Sendable {
    public let lines: [CaptionLine]

    public init(lines: [CaptionLine]) {
        self.lines = lines
    }

    public static let empty = CaptionWindow(lines: [])
    public var text: String { lines.map(\.text).joined(separator: "\n") }
}

public enum CaptionWindowing {
    private struct Token {
        let text: Substring
        let isCommitted: Bool
    }

    /// Packs words forward into stable rows and returns only the newest two.
    /// A row never rewraps merely because a new word arrived: the active row
    /// grows at the bottom, then advances upward as one unit when the next row
    /// begins. Only the model's tentative suffix may still rewrite.
    public static func rolling(
        committed: String,
        tentative: String,
        wordsPerLine: Int
    ) -> CaptionWindow {
        let committedTokens = committed
            .split(whereSeparator: \Character.isWhitespace)
            .map { Token(text: $0, isCommitted: true) }
        let tentativeTokens = tentative
            .split(whereSeparator: \Character.isWhitespace)
            .map { Token(text: $0, isCommitted: false) }
        let allTokens = committedTokens + tentativeTokens
        guard !allTokens.isEmpty else { return .empty }

        let lineCapacity = max(1, wordsPerLine)
        let lineCount = (allTokens.count + lineCapacity - 1) / lineCapacity
        let firstVisibleLine = max(0, lineCount - 2)
        let wasTrimmed = firstVisibleLine > 0

        let lines = (firstVisibleLine..<lineCount).map { lineIndex in
            let start = lineIndex * lineCapacity
            let end = min(start + lineCapacity, allTokens.count)
            let tokens = allTokens[start..<end]
            var stable = tokens.filter(\.isCommitted).map(\.text).joined(separator: " ")
            var volatile = tokens.filter { !$0.isCommitted }.map(\.text).joined(separator: " ")

            if wasTrimmed, lineIndex == firstVisibleLine {
                if !stable.isEmpty {
                    stable = "… " + stable
                } else {
                    volatile = "… " + volatile
                }
            }
            if !stable.isEmpty, !volatile.isEmpty { stable += " " }

            return CaptionLine(
                id: lineIndex,
                committed: stable,
                tentative: volatile
            )
        }
        return CaptionWindow(lines: lines)
    }
}
