import Foundation
import Combine

// MARK: - Weather Models & Store for Notchie (Reference Data & Open-Meteo Integration)

struct NotchieForecastDay: Identifiable, Equatable, Sendable {
    let id: String
    let dayTitle: String
    let weatherCode: Int
    let highTempC: Double
    let lowTempC: Double

    var formattedHighLow: String {
        String(format: "%.1f°C / %.1f°C", highTempC, lowTempC)
    }
}

struct NotchieWeatherSnapshot: Equatable, Sendable {
    var conditionLabel: String
    var currentTempC: Double
    var highTempC: Double
    var lowTempC: Double
    var weatherCode: Int
    var forecastDays: [NotchieForecastDay]
    var sunriseText: String
    var sunsetText: String
    var windText: String

    var formattedCurrentTemp: String {
        String(format: "%.1f °C", currentTempC)
    }

    var formattedHighLow: String {
        String(format: "%.1f° / %.1f°", highTempC, lowTempC)
    }

    nonisolated static func defaultReferenceSnapshot(now: Date = .now) -> NotchieWeatherSnapshot {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE d"

        let sampleCodes = [0, 1, 2, 0]
        let sampleHighs = [23.8, 22.8, 17.8, 17.8]
        let sampleLows = [5.5, 6.1, 6.1, 6.1]

        let days: [NotchieForecastDay] = (0..<4).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: now) ?? now
            let title = formatter.string(from: date)
            return NotchieForecastDay(
                id: "day-\(offset)",
                dayTitle: title,
                weatherCode: sampleCodes[offset],
                highTempC: sampleHighs[offset],
                lowTempC: sampleLows[offset]
            )
        }

        return NotchieWeatherSnapshot(
            conditionLabel: "Dark Sky",
            currentTempC: 21.1,
            highTempC: 23.8,
            lowTempC: 5.5,
            weatherCode: 0,
            forecastDays: days,
            sunriseText: "6:47 AM",
            sunsetText: "7:59 PM",
            windText: "W 10.8 km/h"
        )
    }

    nonisolated static func conditionName(for code: Int) -> String {
        switch code {
        case 0:
            return "Dark Sky"
        case 1, 2:
            return "Partly Cloudy"
        case 3:
            return "Overcast"
        case 45, 48:
            return "Misty Fog"
        case 51, 53, 55, 61, 63, 65, 80, 81, 82:
            return "Light Rain"
        case 71, 73, 75, 77, 85, 86:
            return "Snowfall"
        case 95, 96, 99:
            return "Thunderstorm"
        default:
            return "Dark Sky"
        }
    }

    nonisolated static func compassDirection(for degrees: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let normalized = ((degrees.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        let index = Int((normalized + 22.5) / 45.0) % 8
        return directions[index]
    }
}

@MainActor
final class NotchieWeatherStore: ObservableObject {
    static let shared = NotchieWeatherStore()

    @Published private(set) var snapshot: NotchieWeatherSnapshot = .defaultReferenceSnapshot()
    @Published private(set) var isRefreshing: Bool = false
    private var lastFetchDate: Date?

    private init() {}

    func refreshIfNeeded(force: Bool = false) {
        guard !AppEnvironment.isRunningTests else { return }
        if !force, let lastFetchDate, Date().timeIntervalSince(lastFetchDate) < 900 {
            return
        }
        guard !isRefreshing else { return }
        isRefreshing = true

        guard let url = URL(
            string: "https://api.open-meteo.com/v1/forecast?latitude=37.5665&longitude=126.9780&current=temperature_2m,weather_code,wind_speed_10m,wind_direction_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset&timezone=auto&forecast_days=4"
        ) else {
            isRefreshing = false
            return
        }

        Task {
            defer { self.isRefreshing = false }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }
                if let parsed = Self.parseOpenMeteoResponse(data: data) {
                    self.snapshot = parsed
                    self.lastFetchDate = Date()
                }
            } catch {
                // Keep existing snapshot when offline
            }
        }
    }

    nonisolated static func parseOpenMeteoResponse(data: Data) -> NotchieWeatherSnapshot? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let current = root["current"] as? [String: Any],
              let daily = root["daily"] as? [String: Any] else {
            return nil
        }

        let currentTemp = (current["temperature_2m"] as? NSNumber)?.doubleValue ?? 21.1
        let currentCode = (current["weather_code"] as? NSNumber)?.intValue ?? 0
        let windSpeed = (current["wind_speed_10m"] as? NSNumber)?.doubleValue ?? 10.8
        let windDirDeg = (current["wind_direction_10m"] as? NSNumber)?.doubleValue ?? 270.0

        let dailyTimes = daily["time"] as? [String] ?? []
        let dailyCodes = (daily["weather_code"] as? [NSNumber])?.map(\.intValue) ?? []
        let dailyHighs = (daily["temperature_2m_max"] as? [NSNumber])?.map(\.doubleValue) ?? []
        let dailyLows = (daily["temperature_2m_min"] as? [NSNumber])?.map(\.doubleValue) ?? []
        let sunrises = daily["sunrise"] as? [String] ?? []
        let sunsets = daily["sunset"] as? [String] ?? []

        let inDateFormatter = DateFormatter()
        inDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        inDateFormatter.dateFormat = "yyyy-MM-dd"

        let outDayFormatter = DateFormatter()
        outDayFormatter.locale = Locale(identifier: "en_US_POSIX")
        outDayFormatter.dateFormat = "EEE d"

        var forecastDays: [NotchieForecastDay] = []
        let count = min(4, min(dailyTimes.count, min(dailyHighs.count, dailyLows.count)))
        for idx in 0..<count {
            let dateObj = inDateFormatter.date(from: dailyTimes[idx]) ?? Date()
            let dayTitle = outDayFormatter.string(from: dateObj)
            let code = idx < dailyCodes.count ? dailyCodes[idx] : currentCode
            forecastDays.append(
                NotchieForecastDay(
                    id: dailyTimes[idx],
                    dayTitle: dayTitle,
                    weatherCode: code,
                    highTempC: dailyHighs[idx],
                    lowTempC: dailyLows[idx]
                )
            )
        }

        if forecastDays.isEmpty {
            forecastDays = NotchieWeatherSnapshot.defaultReferenceSnapshot().forecastDays
        }

        let high0 = dailyHighs.first ?? 23.8
        let low0 = dailyLows.first ?? 5.5
        let sunriseText = formatSunTime(sunrises.first) ?? "6:47 AM"
        let sunsetText = formatSunTime(sunsets.first) ?? "7:59 PM"
        let compass = NotchieWeatherSnapshot.compassDirection(for: windDirDeg)
        let windText = String(format: "%@ %.1f km/h", compass, windSpeed)

        return NotchieWeatherSnapshot(
            conditionLabel: NotchieWeatherSnapshot.conditionName(for: currentCode),
            currentTempC: currentTemp,
            highTempC: high0,
            lowTempC: low0,
            weatherCode: currentCode,
            forecastDays: forecastDays,
            sunriseText: sunriseText,
            sunsetText: sunsetText,
            windText: windText
        )
    }

    nonisolated private static func formatSunTime(_ isoString: String?) -> String? {
        guard let isoString else { return nil }
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm"
        guard let date = parser.date(from: isoString) else { return nil }
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_US_POSIX")
        out.dateFormat = "h:mm a"
        return out.string(from: date)
    }
}
