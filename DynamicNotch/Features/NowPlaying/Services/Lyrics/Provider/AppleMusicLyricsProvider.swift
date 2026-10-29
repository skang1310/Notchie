//
//  AppleMusicLyricsProvider.swift
//  DynamicNotch
//

import Foundation
internal import AppKit

@MainActor
final class AppleMusicLyricsProvider: LyricsProviding {
    private var cache: [String: TrackLyrics] = [:]

    func lyrics(for snapshot: NowPlayingSnapshot) async throws -> TrackLyrics? {
        guard let trackKey = snapshot.lyricsLookupKey else { return nil }

        if let cached = cache[trackKey] {
            return cached
        }

        let lyricsText = await Task.detached { () -> String? in
            let scriptText = """
            if application "Music" is running then
                tell application "Music"
                    try
                        if player state is not stopped then
                            return lyrics of current track
                        end if
                    on error
                        return ""
                    end try
                end tell
            end if
            return ""
            """
            guard let script = NSAppleScript(source: scriptText) else { return nil }
            var errorInfo: NSDictionary?
            let desc = script.executeAndReturnError(&errorInfo)
            let str = desc.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return str.isEmpty ? nil : str
        }.value

        guard let lyricsText, !lyricsText.isEmpty else { return nil }

        let parsed = Self.parseLyrics(lyricsText, trackKey: trackKey)
        if let parsed {
            cache[trackKey] = parsed
        }
        return parsed
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
            .filter { !$0.isEmpty }
        guard !rawLines.isEmpty else { return nil }

        let lines = rawLines.enumerated().map { index, line in
            LyricLine(id: index, startTime: nil, text: line)
        }
        return TrackLyrics(trackKey: trackKey, lines: lines, isSynced: false)
    }
}
