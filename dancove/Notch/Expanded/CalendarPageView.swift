import SwiftUI

/// Today on the left (weekday, big date, events), the month grid on the right.
struct CalendarPageView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        TimelineView(.everyMinute) { context in
            HStack(alignment: .top, spacing: 18) {
                TodayColumn(now: context.date)
                    .frame(maxWidth: .infinity, alignment: .leading)
                MonthGrid(now: context.date)
                    .frame(width: 196)
            }
            .padding(.horizontal, 24)
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
    }
}

private struct TodayColumn: View {
    let now: Date

    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(now.formatted(.dateTime.weekday(.wide)))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.red)
            Text(now.formatted(.dateTime.day()))
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .padding(.bottom, 6)

            events
        }
    }

    @ViewBuilder private var events: some View {
        let calendar = app.calendar
        if !calendar.isAuthorized {
            VStack(alignment: .leading, spacing: 6) {
                Text("See your events here")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                Button("Allow Calendar Access") { calendar.requestAccess() }
                    .buttonStyle(NotchPillButtonStyle(kind: .secondary))
            }
        } else if calendar.events.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text("No events")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Text("This day is clear")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(calendar.events.prefix(3)) { event in
                    EventRow(event: event, now: now)
                }
            }
        }
    }
}

private struct EventRow: View {
    let event: CalendarService.Event
    let now: Date

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(event.color.map { Color(cgColor: $0) } ?? .blue)
                .frame(width: 3, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(timeText)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
        }
    }

    private var timeText: String {
        if event.isAllDay { return String(localized: "All day") }
        if event.start <= now {
            return String(localized: "Now · until \(event.end.formatted(date: .omitted, time: .shortened))")
        }
        let minutes = Int(event.start.timeIntervalSince(now) / 60)
        if minutes < 60 { return String(localized: "In \(max(minutes, 1)) min") }
        return "\(event.start.formatted(date: .omitted, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))"
    }
}

private struct MonthGrid: View {
    let now: Date

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(now.formatted(.dateTime.month(.wide)))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.red)
                .padding(.leading, 4)

            Grid(horizontalSpacing: 0, verticalSpacing: 2) {
                GridRow {
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                        Text(symbol)
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(isWeekend(column: index) ? 0.3 : 0.5))
                            .frame(maxWidth: .infinity)
                    }
                }
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    GridRow {
                        ForEach(Array(week.enumerated()), id: \.offset) { column, day in
                            DayCell(day: day, isToday: day.map { calendar.isDate($0, inSameDayAs: now) } ?? false,
                                    isWeekend: isWeekend(column: column), calendar: calendar)
                        }
                    }
                }
            }
        }
    }

    /// Weekday initials starting at the locale's first weekday.
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private func isWeekend(column: Int) -> Bool {
        let weekday = (column + calendar.firstWeekday - 1) % 7 + 1
        return weekday == 1 || weekday == 7
    }

    /// The month's days laid out in week rows, padded with `nil`.
    private var weeks: [[Date?]] {
        guard let interval = calendar.dateInterval(of: .month, for: now),
              let days = calendar.range(of: .day, in: .month, for: now) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in days {
            cells.append(calendar.date(byAdding: .day, value: day - 1, to: interval.start))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }
}

private struct DayCell: View {
    let day: Date?
    let isToday: Bool
    let isWeekend: Bool
    let calendar: Calendar

    var body: some View {
        Group {
            if let day {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 10.5, weight: isToday ? .bold : .medium).monospacedDigit())
                    .foregroundStyle(isToday ? .white : .white.opacity(isWeekend ? 0.35 : 0.75))
                    .frame(width: 20, height: 18)
                    .background {
                        if isToday { Circle().fill(.red) }
                    }
            } else {
                Color.clear.frame(width: 20, height: 18)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
