import Foundation

enum Formatters {
    static let brazilianLocale = Locale(identifier: "pt_BR")

    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = brazilianLocale
        formatter.numberStyle = .currency
        formatter.currencyCode = "BRL"
        return formatter
    }()

    static let decimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = brazilianLocale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    static let integer: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = brazilianLocale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static let dayMonthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = brazilianLocale
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()
}

extension Double {
    var brlCurrency: String {
        Formatters.currency.string(from: NSNumber(value: self)) ?? "R$ 0,00"
    }
}

extension Int {
    var brInteger: String {
        Formatters.integer.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Date {
    var startOfDayInBrazil: Date {
        Calendar.brazil.startOfDay(for: self)
    }

    var endOfDayInBrazil: Date {
        Calendar.brazil.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDayInBrazil) ?? self
    }

    var startOfWeekInBrazil: Date {
        Calendar.brazil.dateInterval(of: .weekOfYear, for: self)?.start ?? self
    }

    var endOfWeekInBrazil: Date {
        Calendar.brazil.dateInterval(of: .weekOfYear, for: self)?.end.addingTimeInterval(-1) ?? self
    }

    var startOfMonthInBrazil: Date {
        Calendar.brazil.dateInterval(of: .month, for: self)?.start ?? self
    }

    var endOfMonthInBrazil: Date {
        Calendar.brazil.dateInterval(of: .month, for: self)?.end.addingTimeInterval(-1) ?? self
    }

    var brDate: String {
        Formatters.dayMonthYear.string(from: self)
    }
}

extension Calendar {
    static let brazil: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "pt_BR")
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .current
        calendar.firstWeekday = 1
        return calendar
    }()
}

extension String {
    var digitsOnly: String {
        filter { $0.isNumber }
    }

    var normalizedWhatsAppPhone: String {
        let numbers = digitsOnly
        if numbers.hasPrefix("55") {
            return numbers
        }
        return "55\(numbers)"
    }
}

enum AnalyticsPeriod: String, CaseIterable, Identifiable {
    case today = "Hoje"
    case week = "Semana"
    case month = "Mês"
    case custom = "Personalizado"

    var id: String { rawValue }

    func range(reference: Date, customStart: Date, customEnd: Date) -> ClosedRange<Date> {
        switch self {
        case .today:
            return reference.startOfDayInBrazil ... reference.endOfDayInBrazil
        case .week:
            return reference.startOfWeekInBrazil ... reference.endOfWeekInBrazil
        case .month:
            return reference.startOfMonthInBrazil ... reference.endOfMonthInBrazil
        case .custom:
            return customStart.startOfDayInBrazil ... customEnd.endOfDayInBrazil
        }
    }
}
