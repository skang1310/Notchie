//
//  KugouLyricsProvider.swift
//  DynamicNotch
//

import Foundation

@MainActor
final class KugouLyricsProvider: LyricsProviding {
    private enum CacheEntry {
        case found(TrackLyrics)
        case missing

        var lyrics: TrackLyrics? {
            switch self {
            case .found(let lyrics):
                return lyrics
            case .missing:
                return nil
            }
        }
    }

    private struct SearchResponse: Decodable {
        let status: Int?
        let errcode: Int?
        let candidates: [Candidate]?
    }

    private struct Candidate: Decodable {
        let id: String
        let accesskey: String
        let duration: Int?
        let score: Int?
        let song: String?
        let singer: String?
    }

    private struct DownloadResponse: Decodable {
        let status: Int?
        let content: String?
    }

    private let session: URLSession
    private let decoder = JSONDecoder()
    private var cache: [String: CacheEntry] = [:]

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: configuration)
    }

    func lyrics(for snapshot: NowPlayingSnapshot) async throws -> TrackLyrics? {
        guard PrivacyPolicy.allows(PrivacyPolicy.onlineLyricsKey) else { return nil }
        guard let trackKey = snapshot.lyricsLookupKey else { return nil }

        if let cached = cache[trackKey] {
            return cached.lyrics
        }

        let rawTitle = snapshot.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = snapshot.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawTitle.isEmpty, !artist.isEmpty else { return nil }

        let cleanTitle = Self.cleanTitle(rawTitle)
        let durationMs = Int(snapshot.duration * 1000)

        // Try search strategies in order:
        // 1. "Artist - RawTitle"
        // 2. "Artist - CleanTitle" (if cleanTitle differs from rawTitle)
        // 3. "RawTitle"
        var searchQueries = ["\(artist) - \(rawTitle)"]
        if cleanTitle != rawTitle && !cleanTitle.isEmpty {
            searchQueries.append("\(artist) - \(cleanTitle)")
        }
        searchQueries.append(rawTitle)

        for query in searchQueries {
            if let lyrics = try await searchAndDownload(query: query, durationMs: durationMs, trackKey: trackKey) {
                cache[trackKey] = .found(lyrics)
                return lyrics
            }
        }

        cache[trackKey] = .missing
        return nil
    }

    private func searchAndDownload(query: String, durationMs: Int, trackKey: String) async throws -> TrackLyrics? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }

        var urlString = "http://krcs.kugou.com/search?ver=1&man=yes&client=mobi&keyword=\(encoded)"
        if durationMs > 0 {
            urlString += "&duration=\(durationMs)"
        }

        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("DynamicNotch/1.0 (Macintosh; Mac OS X)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }

        let searchRes = try decoder.decode(SearchResponse.self, from: data)
        guard let candidates = searchRes.candidates, !candidates.isEmpty else {
            return nil
        }

        // Pick best candidate: closest duration within 6 seconds, or candidate with highest score
        let bestCandidate: Candidate
        if durationMs > 0, let closeCandidate = candidates.first(where: {
            guard let cDur = $0.duration else { return false }
            return abs(cDur - durationMs) <= 6000
        }) {
            bestCandidate = closeCandidate
        } else {
            bestCandidate = candidates.max(by: { ($0.score ?? 0) < ($1.score ?? 0) }) ?? candidates[0]
        }

        guard let dlURL = URL(string: "http://krcs.kugou.com/download?ver=1&client=mobi&id=\(bestCandidate.id)&accesskey=\(bestCandidate.accesskey)&fmt=lrc&charset=utf8") else {
            return nil
        }

        var dlRequest = URLRequest(url: dlURL)
        dlRequest.setValue("DynamicNotch/1.0 (Macintosh; Mac OS X)", forHTTPHeaderField: "User-Agent")

        let (dlData, dlResponse) = try await session.data(for: dlRequest)
        guard let dlHTTP = dlResponse as? HTTPURLResponse, dlHTTP.statusCode == 200 else {
            return nil
        }

        let dlRes = try decoder.decode(DownloadResponse.self, from: dlData)
        guard let b64 = dlRes.content,
              let lrcData = Data(base64Encoded: b64),
              let lrcText = String(data: lrcData, encoding: .utf8) else {
            return nil
        }

        return Self.parseLyrics(lrcText, trackKey: trackKey)
    }

    static func cleanTitle(_ title: String) -> String {
        title.replacingOccurrences(of: #"\s*[\(\[].*?[\)\]]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*-\s*(Single|Remastered|Deluxe|Live|Radio|Acoustic).*"#, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parseLyrics(_ text: String, trackKey: String) -> TrackLyrics? {
        let pattern = #"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]"#
        if let expression = try? NSRegularExpression(pattern: pattern) {
            var syncedLines: [(startTime: TimeInterval, text: String)] = []
            for rawLine in text.components(separatedBy: .newlines) {
                let nsLine = rawLine as NSString
                let fullRange = NSRange(location: 0, length: nsLine.length)
                let matches = expression.matches(in: rawLine, range: fullRange)
                guard let lastMatch = matches.last else { continue }

                let textStart = lastMatch.range.location + lastMatch.range.length
                let lineText = nsLine.substring(from: min(textStart, nsLine.length)).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !lineText.isEmpty else { continue }

                for match in matches {
                    guard
                        match.range(at: 1).location != NSNotFound,
                        match.range(at: 2).location != NSNotFound,
                        let minVal = Int(nsLine.substring(with: match.range(at: 1))),
                        let secVal = Int(nsLine.substring(with: match.range(at: 2)))
                    else { continue }
                    var fraction: TimeInterval = 0
                    if match.range(at: 3).location != NSNotFound {
                        let fStr = nsLine.substring(with: match.range(at: 3))
                        if let fVal = Double(fStr) {
                            fraction = fVal / pow(10.0, Double(fStr.count))
                        }
                    }
                    syncedLines.append((TimeInterval(minVal * 60 + secVal) + fraction, lineText))
                }
            }

            if !syncedLines.isEmpty {
                let sorted = syncedLines.sorted { $0.startTime < $1.startTime }
                let lines = sorted.enumerated().map { index, item in
                    LyricLine(id: index, startTime: item.startTime, text: item.text)
                }
                return TrackLyrics(trackKey: trackKey, lines: lines, isSynced: true)
            }
        }

        let rawLines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("[") }
        guard !rawLines.isEmpty else { return nil }

        let lines = rawLines.enumerated().map { index, line in
            LyricLine(id: index, startTime: nil, text: line)
        }
        return TrackLyrics(trackKey: trackKey, lines: lines, isSynced: false)
    }
}
