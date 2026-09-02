import Foundation

/// Persists aggregate review history that cannot be reconstructed from card-level review logs.
/// The original Recall backup format stores daily review totals in `meta.history`.
enum ReviewHistoryStore {
    private static let key = "recall.aggregateReviewHistory.v1"
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func load() -> [Date: Int] {
        guard let data = UserDefaults.standard.data(forKey: key), let values = try? decoder.decode([String: Int].self, from: data) else { return [:] }
        return values.reduce(into: [:]) { result, entry in
            if let date = parseDate(entry.key), entry.value > 0 { result[Calendar.current.startOfDay(for: date)] = entry.value }
        }
    }

    static func replace(with values: [Date: Int]) {
        let normalized = values.reduce(into: [String: Int]()) { result, entry in
            let count = max(0, entry.value)
            if count > 0 { result[key(for: entry.key)] = count }
        }
        guard let data = try? encoder.encode(normalized) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func exportValues() -> [String: Int] {
        load().reduce(into: [:]) { result, entry in result[key(for: entry.key)] = entry.value }
    }

    static func recordReview(on date: Date = .now) {
        var values = load()
        let day = Calendar.current.startOfDay(for: date)
        values[day, default: 0] += 1
        replace(with: values)
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }

    static func date(from value: String) -> Date? { parseDate(value) }

    private static func key(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}
