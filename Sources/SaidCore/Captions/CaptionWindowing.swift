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

    /// Packs against the actual selected font's glyph widths. Previously completed rows
    /// remain stable as words arrive; explicit appearance changes can reflow the snapshot.
    public static func rolling(
        committed: String,
        tentative: String,
        maximumLineWidth: Double,
        startingAtWord: Int = 0,
        measureText: (String) -> Double
    ) -> CaptionWindow {
        let allTokens = committed.split(whereSeparator: \Character.isWhitespace)
            .map { Token(text: $0, isCommitted: true) }
            + tentative.split(whereSeparator: \Character.isWhitespace)
            .map { Token(text: $0, isCommitted: false) }
        let origin = min(max(0, startingAtWord), allTokens.count)
        let tokens = allTokens.dropFirst(origin)
        guard !tokens.isEmpty else { return .empty }
        // Reserve the continuation mark from the start, avoiding reflow when a row rolls up.
        let available = max(1, maximumLineWidth - measureText("… "))
        var rows: [[Token]] = []
        var row: [Token] = []
        var rowText = ""
        for token in tokens {
            let candidate = rowText.isEmpty ? String(token.text) : rowText + " " + token.text
            if !row.isEmpty && measureText(candidate) > available {
                rows.append(row)
                row = []
                rowText = ""
            }
            row.append(token)
            rowText = rowText.isEmpty ? String(token.text) : rowText + " " + token.text
        }
        if !row.isEmpty { rows.append(row) }
        let first = max(0, rows.count - 2)
        return CaptionWindow(lines: (first..<rows.count).map { index in
            let row = rows[index]
            var stable = row.filter(\.isCommitted).map(\.text).joined(separator: " ")
            var volatile = row.filter { !$0.isCommitted }.map(\.text).joined(separator: " ")
            if (first > 0 || origin > 0) && index == first {
                if stable.isEmpty { volatile = "… " + volatile }
                else { stable = "… " + stable }
            }
            if !stable.isEmpty && !volatile.isEmpty { stable += " " }
            return CaptionLine(id: index, committed: stable, tentative: volatile)
        })
    }


    /// On an explicit appearance change, fill the two rows from the newest word.
    /// Keep this origin for subsequent appends so normal streaming does not rewrap.
    public static func filledRowOrigin(
        text: String, maximumLineWidth: Double, measureText: (String) -> Double
    ) -> Int {
        let words = text.split(whereSeparator: \Character.isWhitespace)
        let available = max(1, maximumLineWidth - measureText("… "))
        var rowText = ""
        var rowCount = 1
        for index in words.indices.reversed() {
            let candidate = rowText.isEmpty ? String(words[index]) : words[index] + " " + rowText
            if !rowText.isEmpty && measureText(candidate) > available {
                rowCount += 1
                if rowCount > 2 { return index + 1 }
                rowText = String(words[index])
            } else {
                rowText = candidate
            }
        }
        return 0
    }

}
