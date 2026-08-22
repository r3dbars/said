public struct CaptionWindow: Equatable, Sendable {
    public let committed: String
    public let tentative: String

    public init(committed: String, tentative: String) {
        self.committed = committed
        self.tentative = tentative
    }
}

public enum CaptionWindowing {
    private struct Token {
        let text: Substring
        let isCommitted: Bool
    }

    /// Keeps a bounded suffix across both stable and tentative text so the
    /// newest words can never be pushed beyond the panel's two-line viewport.
    public static func latest(
        committed: String,
        tentative: String,
        wordLimit: Int
    ) -> CaptionWindow {
        let committedTokens = committed
            .split(whereSeparator: \Character.isWhitespace)
            .map { Token(text: $0, isCommitted: true) }
        let tentativeTokens = tentative
            .split(whereSeparator: \Character.isWhitespace)
            .map { Token(text: $0, isCommitted: false) }
        let allTokens = committedTokens + tentativeTokens
        guard !allTokens.isEmpty else { return CaptionWindow(committed: "", tentative: "") }

        let limit = max(1, wordLimit)
        let wasTrimmed = allTokens.count > limit
        let visible = Array(allTokens.suffix(limit))
        var stable = visible.filter(\.isCommitted).map(\.text).joined(separator: " ")
        var volatile = visible.filter { !$0.isCommitted }.map(\.text).joined(separator: " ")

        if wasTrimmed {
            if !stable.isEmpty {
                stable = "… " + stable
            } else if !volatile.isEmpty {
                volatile = "… " + volatile
            }
        }
        if !stable.isEmpty, !volatile.isEmpty { stable += " " }
        return CaptionWindow(committed: stable, tentative: volatile)
    }
}
