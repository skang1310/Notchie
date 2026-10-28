import Foundation

nonisolated struct ReportCSV: Sendable {
    let headers: [String]
    let rows: [[String]]
    init(_ input: String) throws {
        guard input.utf8.count <= 2_000_000 else { throw SupportToolError.limit }
        var text = input
        if text.hasPrefix("\u{feff}") { text.removeFirst() }
        let chars = Array(text)
        var lines: [[String]] = [], row: [String] = [], field = "", quoted = false, closed = false, i = 0
        func checked(_ rows: Int, _ columns: Int) throws { guard rows <= 50_000, columns <= 200 else { throw SupportToolError.limit } }
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" { if i+1 < chars.count && chars[i+1] == "\"" { field.append("\""); i += 1 } else { quoted = false; closed = true } }
                else { field.append(c) }
            } else if c == "\"" { guard field.isEmpty && !closed else { throw SupportToolError.invalid }; quoted = true }
            else if c == "," { row.append(field); field = ""; closed = false; try checked(lines.count, row.count) }
            else if c == "\n" || c == "\r" || c == "\r\n" {
                row.append(field); if row.contains(where: { !$0.isEmpty }) { lines.append(row) }
                row = []; field = ""; closed = false
                if c == "\r" && i+1 < chars.count && chars[i+1] == "\n" { i += 1 }
                try checked(lines.count, 0)
            } else { guard !closed else { throw SupportToolError.invalid }; field.append(c) }
            i += 1
        }
        guard !quoted else { throw SupportToolError.invalid }
        if !field.isEmpty || !row.isEmpty || closed { row.append(field); lines.append(row) }
        guard let first = lines.first, !first.isEmpty, first.count <= 200, Set(first).count == first.count, first.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }), lines.dropFirst().allSatisfy({ $0.count == first.count }) else { throw SupportToolError.invalid }
        try checked(lines.count, first.count)
        headers = first; rows = Array(lines.dropFirst())
    }
}
nonisolated enum ReportReconciler {
    struct Delta: Sendable { let key: [String]; let a: Decimal?; let b: Decimal?
        var change: Decimal? { guard let a, let b else { return nil }; let d = b-a; return d.isNaN ? nil : d }
        var percent: Decimal? { guard let a, a != 0, let change else { return nil }; let p = change / a * 100; return p.isNaN ? nil : p }
    }
    struct Result: Sendable { let deltas: [Delta]; let totalA: Decimal; let totalB: Decimal; let duplicateRowsA: Int; let duplicateRowsB: Int }
    static func compare(_ a: ReportCSV, _ b: ReportCSV, keys: [String], metric: String) throws -> Result {
        guard !keys.isEmpty, Set(keys).count == keys.count else { throw SupportToolError.invalid }
        func aggregate(_ csv: ReportCSV) throws -> ([String:([String],Decimal)], Int) {
            let indices = try keys.map { key in guard let i = csv.headers.firstIndex(of:key) else { throw SupportToolError.invalid }; return i }
            guard let m = csv.headers.firstIndex(of:metric) else { throw SupportToolError.invalid }
            let regex = try NSRegularExpression(pattern: #"^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$"#)
            var groups: [String:([String],Decimal)] = [:], duplicates = 0
            for row in csv.rows {
                let text = row[m].trimmingCharacters(in: .whitespacesAndNewlines)
                guard regex.firstMatch(in:text,range:NSRange(text.startIndex...,in:text)) != nil, let value = Decimal(string:text,locale:Locale(identifier:"en_US_POSIX")), !value.isNaN else { throw SupportToolError.invalid }
                let values = indices.map { row[$0] }, id = String(decoding: try JSONEncoder().encode(values),as:UTF8.self)
                if let prior = groups[id] { let next = prior.1 + value; guard !next.isNaN else { throw SupportToolError.limit }; groups[id] = (values,next); duplicates += 1 }
                else { groups[id] = (values,value) }
            }
            return (groups,duplicates)
        }
        let (x, dx) = try aggregate(a), (y, dy) = try aggregate(b)
        let deltas = Set(x.keys).union(y.keys).sorted().map { id in Delta(key:x[id]?.0 ?? y[id]!.0,a:x[id]?.1,b:y[id]?.1) }
        func total(_ groups:[String:([String],Decimal)]) throws -> Decimal {
            var result:Decimal = 0
            for value in groups.values { result += value.1; guard !result.isNaN else { throw SupportToolError.limit } }
            return result
        }
        return Result(deltas:deltas,totalA:try total(x),totalB:try total(y),duplicateRowsA:dx,duplicateRowsB:dy)
    }
    static func summary(_ result: Result) -> String {
        func number(_ d:Decimal?) -> String { d.map { NSDecimalNumber(decimal:$0).stringValue } ?? "<missing / n/a>" }
        let lines = result.deltas.filter { $0.a != $0.b }.prefix(300).map {
            "\($0.key.joined(separator:" · ")) | A=\(number($0.a)) | B=\(number($0.b)) | Δ(B−A)=\(number($0.change)) | Δ%=\(number($0.percent))"
        }
        return "A total: \(number(result.totalA))\nB total: \(number(result.totalB))\nRepeated keys aggregated: A=\(result.duplicateRowsA), B=\(result.duplicateRowsB)\nChanged groups: \(result.deltas.filter { $0.a != $0.b }.count)\n\n" + lines.joined(separator:"\n") + "\n\nSame keys are summed. Missing rows are not silently zero-filled. No timezone, currency, attribution or cohort normalization was applied. Differences are observations, not a root-cause diagnosis."
    }
}
