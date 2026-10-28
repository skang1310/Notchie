import Foundation

nonisolated enum LocalCalculator {
    static func evaluate(_ input: String) throws -> Double {
        guard input.count <= 2048 else { throw SupportToolError.limit }
        var parser = Parser(chars: Array(input.filter { !$0.isWhitespace }))
        let result = try parser.expression(0)
        guard parser.index == parser.chars.count, result.isFinite else { throw SupportToolError.invalid }
        return result
    }
    private struct Parser {
        let chars: [Character]; var index = 0
        mutating func take(_ c: Character) -> Bool { if index < chars.count && chars[index] == c { index += 1; return true }; return false }
        mutating func expression(_ depth: Int) throws -> Double {
            guard depth < 64 else { throw SupportToolError.limit }
            var result = try term(depth + 1)
            while index < chars.count {
                if take("+") { result += try term(depth + 1) }
                else if take("-") { result -= try term(depth + 1) }
                else { break }
            }; return result
        }
        mutating func term(_ depth: Int) throws -> Double {
            var result = try atom(depth + 1)
            while index < chars.count {
                if take("*") { result *= try atom(depth + 1) }
                else if take("/") { let divisor = try atom(depth + 1); guard divisor != 0 else { throw SupportToolError.divideByZero }; result /= divisor }
                else { break }
            }; return result
        }
        mutating func atom(_ depth: Int) throws -> Double {
            guard depth < 64 else { throw SupportToolError.limit }
            if take("+") { return try atom(depth + 1) }
            if take("-") { return try -atom(depth + 1) }
            var value: Double
            if take("(") { value = try expression(depth + 1); guard take(")") else { throw SupportToolError.invalid } }
            else {
                let start = index
                while index < chars.count && (chars[index].isNumber || chars[index] == ".") { index += 1 }
                if index < chars.count && (chars[index] == "e" || chars[index] == "E") {
                    index += 1; if index < chars.count && (chars[index] == "+" || chars[index] == "-") { index += 1 }
                    while index < chars.count && chars[index].isNumber { index += 1 }
                }
                guard let number = Double(String(chars[start..<index])) else { throw SupportToolError.invalid }; value = number
            }
            while take("%") { value /= 100 }
            return value
        }
    }
    static let units: [String: (group: String, factor: Double)] = [
        "B": ("data", 1), "KB": ("data", 1000), "MB": ("data", 1e6), "GB": ("data", 1e9), "KiB": ("data", 1024), "MiB": ("data", 1048576), "GiB": ("data", 1073741824),
        "ms": ("time", 0.001), "s": ("time", 1), "min": ("time", 60), "h": ("time", 3600),
        "mm": ("length", 0.001), "cm": ("length", 0.01), "m": ("length", 1), "km": ("length", 1000), "in": ("length", 0.0254), "ft": ("length", 0.3048)
    ]
    static func convert(_ value: Double, from: String, to: String) throws -> Double {
        guard value.isFinite else { throw SupportToolError.invalid }
        if ["°C", "°F", "K"].contains(from), ["°C", "°F", "K"].contains(to) {
            let c = from == "°C" ? value : from == "°F" ? (value - 32) * 5 / 9 : value - 273.15
            guard c >= -273.15 else { throw SupportToolError.invalid }
            return to == "°C" ? c : to == "°F" ? c * 9 / 5 + 32 : c + 273.15
        }
        guard let a = units[from], let b = units[to], a.group == b.group else { throw SupportToolError.invalid }
        let result = value * a.factor / b.factor
        guard result.isFinite else { throw SupportToolError.invalid }; return result
    }
}
