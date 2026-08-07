import Foundation

/// A single cell in the month grid.
struct CalendarDay: Hashable {
    let date: Date
    let isInDisplayedMonth: Bool
    let isToday: Bool
}

/// A pure, Monday-first month grid used by the todo due-date picker.
struct MonthCalendar {
    /// Quick presets offered above the calendar grid.
    enum QuickDate: CaseIterable {
        case today
        case tomorrow
        case nextWeek
    }

    private let calendar: Calendar
    private(set) var displayedMonthStart: Date

    init(containing date: Date = Date(), calendar: Calendar? = nil) {
        var base = calendar ?? Calendar.current
        base.firstWeekday = 2 // Monday
        self.calendar = base
        let components = base.dateComponents([.year, .month], from: date)
        self.displayedMonthStart = base.date(from: components) ?? base.startOfDay(for: date)
    }

    /// Always returns exactly 42 cells (6 weeks) so the grid never jumps in height.
    var days: [CalendarDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonthStart),
              let firstWeekInterval = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start) else {
            return []
        }
        let today = calendar.startOfDay(for: Date())
        return (0..<42).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: firstWeekInterval.start) else {
                return nil
            }
            return CalendarDay(
                date: date,
                isInDisplayedMonth: monthInterval.contains(date),
                isToday: date == today
            )
        }
    }

    /// Weekday symbols ordered to match the grid (Monday first).
    var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    mutating func showNextMonth() {
        advance(by: 1)
    }

    mutating func showPreviousMonth() {
        advance(by: -1)
    }

    mutating func show(containing date: Date) {
        let components = calendar.dateComponents([.year, .month], from: date)
        displayedMonthStart = calendar.date(from: components) ?? displayedMonthStart
    }

    func isSameDay(_ lhs: Date, as rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private mutating func advance(by months: Int) {
        if let next = calendar.date(byAdding: .month, value: months, to: displayedMonthStart) {
            displayedMonthStart = next
        }
    }

    static func quickDate(_ option: QuickDate, from base: Date = Date(), calendar: Calendar? = nil) -> Date {
        var cal = calendar ?? Calendar.current
        cal.firstWeekday = 2
        let start = cal.startOfDay(for: base)
        switch option {
        case .today:
            return start
        case .tomorrow:
            return cal.date(byAdding: .day, value: 1, to: start) ?? start
        case .nextWeek:
            return cal.date(byAdding: .day, value: 7, to: start) ?? start
        }
    }
}
