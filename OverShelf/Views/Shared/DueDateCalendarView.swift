import SwiftUI

/// A compact, themed month calendar for picking a todo due date.
/// Replaces the oversized native graphical DatePicker popover.
struct DueDateCalendarView: View {
    let selected: Date?
    let onSelect: (Date) -> Void
    let onClear: () -> Void

    @State private var month: MonthCalendar

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    init(selected: Date?, onSelect: @escaping (Date) -> Void, onClear: @escaping () -> Void) {
        self.selected = selected
        self.onSelect = onSelect
        self.onClear = onClear
        _month = State(initialValue: MonthCalendar(containing: selected ?? Date()))
    }

    var body: some View {
        VStack(spacing: 8) {
            quickActions
            Divider()
            monthHeader
            weekdayHeader
            dayGrid
        }
        .padding(10)
        .frame(width: 224)
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        HStack(spacing: 4) {
            quickAction("Today") { pick(.today) }
            quickAction("Tomorrow") { pick(.tomorrow) }
            quickAction("+1 Week") { pick(.nextWeek) }
            Spacer()
            Button("Clear") { onClear() }
                .font(.system(size: 10))
                .buttonStyle(.plain)
                .foregroundStyle(selected == nil ? Color.clear : Color.red)
                .disabled(selected == nil)
        }
    }

    private func quickAction(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Theme.fieldBg)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private func pick(_ option: MonthCalendar.QuickDate) {
        let date = MonthCalendar.quickDate(option)
        month.show(containing: date)
        onSelect(date)
    }

    // MARK: - Month navigation

    private var monthHeader: some View {
        HStack {
            Button { month.showPreviousMonth() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(month.displayedMonthStart.formatted(.dateTime.year().month(.wide)))
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)

            Button { month.showNextMonth() } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(month.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(height: 16)
            }
        }
    }

    // MARK: - Day grid

    private var dayGrid: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(month.days, id: \.date) { day in
                dayCell(day)
            }
        }
    }

    private func dayCell(_ day: CalendarDay) -> some View {
        let isSelected = selected.map { month.isSameDay(day.date, as: $0) } ?? false
        return Button {
            onSelect(month.startOfDay(for: day.date))
        } label: {
            Text(day.date.formatted(.dateTime.day()))
                .font(.system(size: 11, weight: day.isToday ? .semibold : .regular))
                .foregroundStyle(foreground(for: day, isSelected: isSelected))
                .frame(width: 26, height: 26)
                .background(background(for: day, isSelected: isSelected))
                .clipShape(Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func foreground(for day: CalendarDay, isSelected: Bool) -> Color {
        if isSelected { return .white }
        if day.isToday { return .accentColor }
        return day.isInDisplayedMonth ? .primary : Color(nsColor: .tertiaryLabelColor)
    }

    @ViewBuilder
    private func background(for day: CalendarDay, isSelected: Bool) -> some View {
        if isSelected {
            Circle().fill(Color.accentColor)
        } else if day.isToday {
            Circle().stroke(Color.accentColor, lineWidth: 1)
        } else {
            Circle().fill(Color.clear)
        }
    }
}
