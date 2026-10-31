//
//  CinemaReleaseItem.swift
//  DynamicNotch
//

import Foundation
import SwiftUI

public enum CinemaPlatform: String, CaseIterable, Identifiable, Sendable {
    case all
    case netflix
    case theater
    case disney
    case apple

    public var id: String { rawValue }

    public func localizedName(isKorean: Bool) -> String {
        switch self {
        case .all: return isKorean ? "전체" : "All"
        case .netflix: return isKorean ? "넷플릭스" : "Netflix"
        case .theater: return isKorean ? "극장 개봉" : "Theatrical"
        case .disney: return "Disney+"
        case .apple: return "Apple TV+"
        }
    }

    public var accentColor: Color {
        switch self {
        case .all: return Color.white
        case .netflix: return Color(red: 0.90, green: 0.12, blue: 0.16) // Netflix Crimson
        case .theater: return Color(red: 0.98, green: 0.72, blue: 0.18) // Cinema Gold
        case .disney: return Color(red: 0.18, green: 0.48, blue: 0.98) // Disney Blue
        case .apple: return Color(red: 0.75, green: 0.75, blue: 0.82) // Apple Silver
        }
    }

    public var iconName: String {
        switch self {
        case .all: return "sparkles.tv"
        case .netflix: return "play.rectangle.fill"
        case .theater: return "film.fill"
        case .disney: return "sparkles"
        case .apple: return "appletvremote.gen4.fill"
        }
    }
}

public struct CinemaReleaseItem: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let originalTitle: String
    public let platform: CinemaPlatform
    public let releaseDate: Date
    public let genre: String
    public let directorOrCast: String
    public let synopsis: String
    public let trailerURL: URL?
    public let rating: String
    public let posterGradient: [Color]
    public let iconSymbol: String

    public init(
        id: UUID = UUID(),
        title: String,
        originalTitle: String,
        platform: CinemaPlatform,
        releaseDate: Date,
        genre: String,
        directorOrCast: String,
        synopsis: String,
        trailerURL: URL?,
        rating: String = "15+",
        posterGradient: [Color] = [Color.purple.opacity(0.6), Color.black],
        iconSymbol: String = "film"
    ) {
        self.id = id
        self.title = title
        self.originalTitle = originalTitle
        self.platform = platform
        self.releaseDate = releaseDate
        self.genre = genre
        self.directorOrCast = directorOrCast
        self.synopsis = synopsis
        self.trailerURL = trailerURL
        self.rating = rating
        self.posterGradient = posterGradient
        self.iconSymbol = iconSymbol
    }

    public var daysRemaining: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfRelease = calendar.startOfDay(for: releaseDate)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfRelease)
        return components.day ?? 0
    }

    public var formattedDDay: String {
        let days = daysRemaining
        if days == 0 {
            return "D-DAY"
        } else if days > 0 {
            return "D-\(days)"
        } else {
            return "공개됨"
        }
    }

    public var formattedReleaseDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E)"
        return formatter.string(from: releaseDate)
    }

    public var shortDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "MM.dd"
        return formatter.string(from: releaseDate)
    }
}
