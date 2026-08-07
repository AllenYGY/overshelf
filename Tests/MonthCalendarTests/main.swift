import Foundation

func fail(_ message: String) -> Never {
    fputs("CALENDAR TEST FAIL: \(message)\n", stderr)
    exit(1)
}

var gregorian = Calendar(identifier: .gregorian)
gregorian.timeZone = TimeZone(identifier: "UTC")!

func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    guard let date = gregorian.date(from: DateComponents(year: year, month: month, day: day)) else {
        fail("test fixture date \(year)-\(month)-\(day) should be constructible")
    }
    return date
}

// August 2026 starts on a Saturday, so a Monday-first grid begins on Monday July 27.
var calendar = MonthCalendar(containing: makeDate(2026, 8, 15), calendar: gregorian)
let days = calendar.days

guard days.count == 42 else {
    fail("the month grid should always contain 42 day cells, got \(days.count)")
}
guard gregorian.component(.month, from: days[0].date) == 7,
      gregorian.component(.day, from: days[0].date) == 27 else {
    fail("a Monday-first August 2026 grid should start on July 27")
}
guard gregorian.component(.weekday, from: days[0].date) == 2 else {
    fail("the first grid cell should be a Monday")
}
guard !days[0].isInDisplayedMonth else {
    fail("leading cells from the previous month should be marked as outside the displayed month")
}
guard days[5].isInDisplayedMonth,
      gregorian.component(.day, from: days[5].date) == 1 else {
    fail("August 1 (a Saturday) should be the 6th cell of the grid")
}
guard gregorian.component(.month, from: days[41].date) == 9,
      gregorian.component(.day, from: days[41].date) == 6,
      !days[41].isInDisplayedMonth else {
    fail("the 42-cell grid for August 2026 should end on September 6")
}

// Month navigation
calendar.showNextMonth()
guard gregorian.component(.month, from: calendar.displayedMonthStart) == 9,
      gregorian.component(.year, from: calendar.displayedMonthStart) == 2026 else {
    fail("showNextMonth should move to September 2026")
}
calendar.showPreviousMonth()
calendar.showPreviousMonth()
guard gregorian.component(.month, from: calendar.displayedMonthStart) == 7 else {
    fail("showPreviousMonth should move back across months")
}

// December -> January crosses the year boundary
var yearEdge = MonthCalendar(containing: makeDate(2026, 12, 10), calendar: gregorian)
yearEdge.showNextMonth()
guard gregorian.component(.month, from: yearEdge.displayedMonthStart) == 1,
      gregorian.component(.year, from: yearEdge.displayedMonthStart) == 2027 else {
    fail("showNextMonth from December should land in January of the next year")
}

// Today is marked inside the current month
let thisMonth = MonthCalendar(containing: Date(), calendar: gregorian)
guard thisMonth.days.contains(where: { $0.isToday && $0.isInDisplayedMonth }) else {
    fail("the current month grid should mark today")
}

// Quick date presets
let base = makeDate(2026, 8, 6)
guard MonthCalendar.quickDate(.today, from: base, calendar: gregorian) == makeDate(2026, 8, 6) else {
    fail("today should resolve to the start of the given day")
}
guard MonthCalendar.quickDate(.tomorrow, from: base, calendar: gregorian) == makeDate(2026, 8, 7) else {
    fail("tomorrow should resolve to the start of the next day")
}
guard MonthCalendar.quickDate(.nextWeek, from: base, calendar: gregorian) == makeDate(2026, 8, 13) else {
    fail("next week should resolve seven days ahead")
}

print("Month calendar tests passed")
