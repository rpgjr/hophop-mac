import SwiftUI

struct CalendarView: View {
    @Environment(ApplicationStore.self) private var store
    @State private var month = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: .now)
    )!

    @State private var futureNotice = false
    private let calendar = Calendar.current
    @AppStorage(AppSettings.weekStart) private var weekStart = 0
    private let allWeekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private var weekdays: [String] { Array(allWeekdays[weekStart...] + allWeekdays[..<weekStart]) }

    private var counts: [String: Int] {
        Dictionary(grouping: store.applications, by: \.appliedDate).mapValues(\.count)
    }

    private var firstWeekday: Int { (calendar.component(.weekday, from: month) - 1 - weekStart + 7) % 7 }

    private var daysInMonth: Int { calendar.range(of: .day, in: .month, for: month)!.count }

    private var lastDay: Date { calendar.date(byAdding: .day, value: daysInMonth - 1, to: month)! }

    /// Day numbers by week, padded so every week has seven slots.
    private var weeks: [[Int?]] {
        let slots: [Int?] = Array(repeating: nil, count: firstWeekday) + (1...daysInMonth).map { Optional($0) }
        let padded = slots + Array(repeating: nil, count: (7 - slots.count % 7) % 7)
        return stride(from: 0, to: padded.count, by: 7).map { Array(padded[$0..<$0 + 7]) }
    }

    // No scrolling: the weeks share whatever height the window has.
    var body: some View {
        VStack(spacing: 12) {
            header

            HStack(spacing: 8) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(HH.font(12, .medium))
                        .foregroundStyle(HH.muted)
                        .frame(maxWidth: .infinity)
                }
            }

            VStack(spacing: 8) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 8) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                            if let day {
                                cell(day)
                            } else {
                                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(18)
        .hhCard(radius: 14)
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .padding(.bottom, 26)
        .overlay(alignment: .bottom) {
            if futureNotice {
                Label("Cannot add applications for future dates", systemImage: "info.circle")
                    .font(HH.font(13, .semibold))
                    .foregroundStyle(HH.warnInk)
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(Capsule().fill(HH.warnSoft))
                    .overlay(Capsule().stroke(HH.warnInk.opacity(0.3), lineWidth: 1))
                    .padding(.bottom, 40)
                    .transition(.opacity)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .task(id: month) {
            await store.loadApplications(from: month, to: lastDay)
        }
    }

    private var header: some View {
        HStack {
            Button {
                changeMonth(-1)
            } label: {
                Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.hh(.plain, square: true))
            .accessibilityLabel("Previous month")

            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(HH.display(22))
                .foregroundStyle(HH.ink)
            Spacer()

            Button {
                changeMonth(1)
            } label: {
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.hh(.plain, square: true))
            .accessibilityLabel("Next month")
        }
    }

    private func cell(_ day: Int) -> some View {
        let date = calendar.date(byAdding: .day, value: day - 1, to: month)!
        let count = counts[APIClient.day(date)] ?? 0
        return DayCell(day: day, count: count, isToday: calendar.isDateInToday(date)) {
            if date > .now {
                showFutureNotice()
            } else {
                store.page = .day(date)
            }
        }
    }

    private func showFutureNotice() {
        withAnimation(.easeOut(duration: 0.15)) { futureNotice = true }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.easeIn(duration: 0.2)) { futureNotice = false }
        }
    }

    private func changeMonth(_ offset: Int) {
        month = calendar.date(byAdding: .month, value: offset, to: month)!
    }
}

private struct DayCell: View {
    let day: Int
    let count: Int
    let isToday: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                Text("\(day)")
                    .font(HH.font(14, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(isToday ? HH.onPrimary : HH.ink)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(isToday ? HH.primary : Color.clear))
                if count > 0 {
                    Text("\(count) applied")
                        .font(HH.font(11, .semibold))
                        .foregroundStyle(HH.primaryInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(HH.primarySoft))
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(hovering ? HH.sunken : HH.surface))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isToday ? HH.primary : HH.border, lineWidth: 1))
            .animation(.easeOut(duration: 0.12), value: hovering)
            .contentShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(count > 0 ? "Day \(day), \(count) applied" : "Day \(day)")
    }
}
