import Foundation

enum ClipboardKind: String, CaseIterable, Identifiable {
    case all, text, links, code
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: privacyText("All items", "전체 항목")
        case .text: privacyText("Text", "텍스트")
        case .links: privacyText("Links", "링크")
        case .code: privacyText("Code", "코드")
        }
    }
    var symbol: String {
        switch self {
        case .all: "line.3.horizontal.decrease"
        case .text: "text.alignleft"
        case .links: "link"
        case .code: "curlybraces"
        }
    }
    static func classify(_ text: String) -> Self {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.contains(where: \.isWhitespace), let url = URL(string: clean),
           ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil { return .links }
        let markers = ["const ", "let ", "func ", "function ", "import ", "class ", "SELECT ", "{\"", "</", "=>", "border-radius:"]
        if markers.contains(where: { clean.hasPrefix($0) }) || clean.contains("\n    ") { return .code }
        return .text
    }
}

extension SavedSnippet {
    var clipboardKind: ClipboardKind { ClipboardKind.classify(text) }
    var previewLines: [String] {
        // Bound layout work on large clipboard items without modifying stored/copied text.
        let lines = text.prefix(500).split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return Array(lines.prefix(2))
    }
}
