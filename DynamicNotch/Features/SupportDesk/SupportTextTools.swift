import Foundation

nonisolated enum SupportToolError: LocalizedError {
    case invalid, limit, divideByZero, unsafeArchive, duplicateNames
    var errorDescription: String? {
        switch self {
        case .invalid: return "Unsupported or invalid input."
        case .limit: return "Input exceeds the local tool limit."
        case .divideByZero: return "Division by zero."
        case .unsafeArchive: return "Archive is unsupported or unsafe (path, link, size or encryption)."
        case .duplicateNames: return "Files have duplicate names; select uniquely named files."
        }
    }
}
nonisolated enum SupportTextTools {
    static let limit = 1_000_000
    static func json(_ text: String, compact: Bool = false) throws -> String {
        guard text.utf8.count <= limit else { throw SupportToolError.limit }
        let object = try JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed])
        var options: JSONSerialization.WritingOptions = [.sortedKeys, .fragmentsAllowed]
        if !compact { options.insert(.prettyPrinted) }
        return String(decoding: try JSONSerialization.data(withJSONObject: object, options: options), as: UTF8.self)
    }
    static func query(_ input: String) throws -> [(String, String)] {
        guard input.utf8.count <= limit else { throw SupportToolError.limit }
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = URLComponents(string: text.contains("://") ? text : "https://local.invalid/?" + text.trimmingCharacters(in: CharacterSet(charactersIn: "?")))
        guard let items = components?.queryItems, !items.isEmpty else { throw SupportToolError.invalid }
        return items.map { ($0.name, $0.value ?? "") }
    }
    static func decodedQuery(_ text: String) throws -> String {
        let rows = try query(text).map { ["name": $0.0, "value": $0.1] }
        return String(decoding: try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self)
    }
    static func diff(_ left: String, _ right: String) throws -> String {
        guard left.utf8.count <= limit, right.utf8.count <= limit else { throw SupportToolError.limit }
        let a = try JSONSerialization.jsonObject(with: Data(left.utf8), options: [.fragmentsAllowed])
        let b = try JSONSerialization.jsonObject(with: Data(right.utf8), options: [.fragmentsAllowed])
        var lines: [String] = [], visited = 0
        func walk(_ a: Any?, _ b: Any?, _ path: String, _ depth: Int) throws {
            visited += 1
            guard depth < 40, visited <= 5000 else { throw SupportToolError.limit }
            if let x = a as? [String: Any], let y = b as? [String: Any] {
                for key in Set(x.keys).union(y.keys).sorted() { try walk(x[key], y[key], path + "/" + key.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1"), depth + 1) }
            } else if let x = a as? [Any], let y = b as? [Any] {
                for i in 0..<max(x.count, y.count) { try walk(i < x.count ? x[i] : nil, i < y.count ? y[i] : nil, path + "/\(i)", depth + 1) }
            } else {
                func value(_ o: Any?) -> String {
                    guard let o else { return "<missing>" }
                    return (try? String(decoding: JSONSerialization.data(withJSONObject: o, options: [.sortedKeys, .fragmentsAllowed]), as: UTF8.self)) ?? "?"
                }
                let x = value(a), y = value(b)
                if x != y { lines.append("\(path.isEmpty ? "/" : path): \(x) → \(y)") }
            }
        }
        try walk(a, b, "", 0)
        return lines.isEmpty ? "No structural differences." : lines.joined(separator: "\n")
    }
    static func redacted(_ text: String) throws -> String {
        guard text.utf8.count <= limit else { throw SupportToolError.limit }
        var result = text
        let patterns = [
            #"(?i)(Bearer\s+)[A-Za-z0-9._~+/-]+"#,
            #"(?i)(\"?(?:api[_-]?key|sdk[_-]?(?:key|secret)|secret|password|token|authorization|sdid|idfa|idfv|aifa|android[_-]?id|asid|andi|custom_user_id|a)\"?\s*[:=]\s*\"?)([^\"\s&,}\n]+)"#,
            #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#,
            #"(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b"#
        ]
        for (i, pattern) in patterns.enumerated() {
            let regex = try NSRegularExpression(pattern: pattern)
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: i < 2 ? "$1<redacted>" : "<redacted>")
        }
        return result
    }
    /// Structural observations only; does not send events or infer successful attribution.
    static func singularSummary(_ text: String) throws -> String {
        guard text.utf8.count <= limit else { throw SupportToolError.limit }
        let pairs: [(String, String)]
        if let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] {
            guard text.utf8.count <= limit else { throw SupportToolError.limit }
            pairs = object.keys.sorted().map { ($0, String(describing: object[$0]!)) }
        } else { pairs = try query(text) }
        let names = pairs.map(\.0), duplicate = Dictionary(grouping: names, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
        let relevant = ["p", "n", "a", "sdid", "idfa", "idfv", "aifa", "andi", "asid", "ip", "utime", "e"]
        let present = relevant.filter { names.contains($0) }
        let empty = pairs.filter { $0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.map(\.0)
        return "Fields: \(pairs.count)\nRecognized keys: \(present.joined(separator: ", "))\nDuplicate keys: \(duplicate.joined(separator: ", "))\nEmpty values: \(empty.joined(separator: ", "))\n\nLocal structure check only. Endpoint/version/platform requirements must be checked against the official reference. No request was sent."
    }
}
