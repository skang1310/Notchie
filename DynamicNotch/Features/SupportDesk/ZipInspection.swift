import Foundation
import zlib

nonisolated struct ZipInspection {
    let names: [String]
    let expandedBytes: UInt64
    init(data: Data) throws {
        guard data.count >= 22, data.count <= 256 * 1024 * 1024 else { throw SupportToolError.unsafeArchive }
        func u16(_ p: Int) throws -> Int { guard p >= 0, p + 2 <= data.count else { throw SupportToolError.unsafeArchive }; return Int(data[p]) | Int(data[p+1]) << 8 }
        func u32(_ p: Int) throws -> UInt32 { guard p >= 0, p + 4 <= data.count else { throw SupportToolError.unsafeArchive }; return (0..<4).reduce(UInt32(0)) { $0 | UInt32(data[p+$1]) << (8*$1) } }
        var end: Int?
        for p in stride(from: data.count - 22, through: max(0, data.count - 65557), by: -1) {
            if try u32(p) == 0x06054b50, p + 22 + (try u16(p + 20)) == data.count { end = p; break }
        }
        guard let end, try u16(end+4) == 0, try u16(end+6) == 0 else { throw SupportToolError.unsafeArchive }
        let count = try u16(end+10), size = Int(try u32(end+12)), start = Int(try u32(end+16))
        guard count > 0, count <= 2000, try u16(end+8) == count, start >= 0, start + size == end else { throw SupportToolError.unsafeArchive }
        var cursor = start, names: [String] = [], seen = Set<String>(), total: UInt64 = 0
        for _ in 0..<count {
            guard cursor + 46 <= end, try u32(cursor) == 0x02014b50 else { throw SupportToolError.unsafeArchive }
            let flags = try u16(cursor+8), method = try u16(cursor+10), compressed = UInt64(try u32(cursor+20)), expanded = UInt64(try u32(cursor+24))
            let length = try u16(cursor+28), extra = try u16(cursor+30), comment = try u16(cursor+32), local = Int(try u32(cursor+42))
            let mode = (try u32(cursor+38) >> 16) & 0xf000
            guard flags & 1 == 0, [0,8].contains(method), mode != 0xa000, expanded != UInt64(UInt32.max), compressed != UInt64(UInt32.max),
                  cursor + 46 + length + extra + comment <= end,
                  let name = String(data: data.subdata(in: cursor+46..<cursor+46+length), encoding: .utf8), !name.isEmpty,
                  !name.hasPrefix("/"), !name.contains("\\"), !name.contains(":"), !name.contains("\0"),
                  !name.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0 == ".." || $0 == "." }) else { throw SupportToolError.unsafeArchive }
            let identity = name.precomposedStringWithCanonicalMapping.lowercased()
            guard seen.insert(identity).inserted, local >= 0, local + 30 <= start, try u32(local) == 0x04034b50,
                  try u16(local+6) & 1 == 0, try u16(local+8) == method else { throw SupportToolError.unsafeArchive }
            let localLength = try u16(local+26), localExtra = try u16(local+28)
            guard local + 30 + localLength + localExtra + Int(compressed) <= start,
                  data.subdata(in: local+30..<local+30+localLength) == data.subdata(in: cursor+46..<cursor+46+length) else { throw SupportToolError.unsafeArchive }
            let payloadStart = local + 30 + localLength + localExtra
            let payload = data.subdata(in: payloadStart..<payloadStart + Int(compressed))
            try Self.validatePayload(payload, method: method, expanded: expanded, crc: u32(cursor+16))
            total += expanded
            guard total <= 512 * 1024 * 1024, expanded <= 20 * 1024 * 1024 || expanded / max(1, compressed) <= 1000 else { throw SupportToolError.unsafeArchive }
            names.append(name); cursor += 46 + length + extra + comment
        }
        guard cursor == end else { throw SupportToolError.unsafeArchive }
        self.names = names; expandedBytes = total
    }
    /// Fully decode into a fixed buffer before extraction. Untrusted ZIP size fields
    /// cannot authorize a larger write or hide an unbounded deflate stream.
    private static func validatePayload(_ data: Data, method: Int, expanded: UInt64, crc: UInt32) throws {
        if method == 0 {
            guard data.count == expanded else { throw SupportToolError.unsafeArchive }
            let actual = data.withUnsafeBytes { crc32(0, $0.bindMemory(to: Bytef.self).baseAddress, uInt(data.count)) }
            guard UInt32(actual) == crc else { throw SupportToolError.unsafeArchive }; return
        }
        var stream = z_stream()
        guard inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else { throw SupportToolError.unsafeArchive }
        defer { inflateEnd(&stream) }
        var buffer = [UInt8](repeating: 0, count: 65536)
        var checksum: uLong = 0
        try data.withUnsafeBytes { input in
            stream.next_in = UnsafeMutablePointer(mutating: input.bindMemory(to: Bytef.self).baseAddress)
            stream.avail_in = uInt(data.count)
            var status: Int32 = Z_OK
            repeat {
                status = buffer.withUnsafeMutableBufferPointer { output in
                    stream.next_out = output.baseAddress; stream.avail_out = uInt(output.count)
                    let result = inflate(&stream, Z_NO_FLUSH)
                    checksum = crc32(checksum, output.baseAddress, uInt(output.count) - stream.avail_out)
                    return result
                }
                guard stream.total_out <= expanded, status == Z_OK || status == Z_STREAM_END else { throw SupportToolError.unsafeArchive }
                if status == Z_OK && stream.avail_in == 0 && stream.avail_out > 0 { throw SupportToolError.unsafeArchive }
            } while status != Z_STREAM_END
            guard stream.total_out == expanded, stream.avail_in == 0, UInt32(checksum) == crc else { throw SupportToolError.unsafeArchive }
        }
    }

}
