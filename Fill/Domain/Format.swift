import Foundation

public enum Format {
    private static var bucksNumber: NumberFormatter {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en-IN")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }

    /// Neutral bucks, no currency symbols anywhere. The currency param is kept
    /// only so stored rewards (incl. the USD seed) keep compiling; it is ignored.
    public static func money(_ v: Decimal, currency: String = "INR") -> String {
        let n = bucksNumber.string(from: v as NSDecimalNumber) ?? "\(v)"
        return "\(n) bucks"
    }

    /// Metric values: whole with grouping, except run/sleep 1 decimal.
    public static func metric(_ v: Double, metric: Metric) -> String {
        switch metric {
        case .run, .sleep:
            let f = NumberFormatter()
            f.locale = Locale(identifier: "en-IN")
            f.numberStyle = .decimal
            f.minimumFractionDigits = 1; f.maximumFractionDigits = 1
            return f.string(from: NSNumber(value: v)) ?? "\(v)"
        default:
            let f = NumberFormatter()
            f.locale = Locale(identifier: "en-IN")
            f.numberStyle = .decimal
            f.maximumFractionDigits = 0
            return f.string(from: NSNumber(value: v.rounded())) ?? "\(Int(v))"
        }
    }

    public static func int(_ v: Int) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en-IN")
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    /// "5 Nov".
    public static func date(_ key: DayKey) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        var comp = DateComponents()
        comp.year = key.year; comp.month = key.month; comp.day = key.day
        guard let d = cal.date(from: comp) else { return key.key }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en-GB")
        f.dateFormat = "d MMM"
        return f.string(from: d)
    }

    /// "ENDS 5 NOV".
    public static func goalDate(_ key: DayKey) -> String {
        "ENDS \(date(key).uppercased())"
    }
}
