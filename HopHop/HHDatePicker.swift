import SwiftUI

/// A month grid to pick one day from. Days after `max` cannot be picked.
struct HHCalendarPanel: View {
    @Binding var selection: Date
    var max: Date?

    @AppStorage(AppSettings.weekStart) private var weekStart = 0
    @State private var month: Date

    private let calendar = Calendar.current
    private let allWeekdays = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    init(selection: Binding<Date>, max: Date? = nil) {
        _selection = selection
        self.max = max
        let calendar = Calendar.current
        _month = State(initialValue: calendar.date(from: calendar.dateComponents([.year, .month], from: selection.wrappedValue))!)
    }

    private var weekdays: [String] { Array(allWeekdays[weekStart...] + allWeekdays[..<weekStart]) }

    private var canGoForward: Bool {
        guard let max else { return true }
        return calendar.date(byAdding: .month, value: 1, to: month)! <= max
    }

    /// Day slots by week, with nil for the blanks around the month.
    private var weeks: [[Date?]] {
        let lead = (calendar.component(.weekday, from: month) - 1 - weekStart + 7) % 7
        let count = calendar.range(of: .day, in: .month, for: month)!.count
        var slots: [Date?] = Array(repeating: nil, count: lead)
        slots += (0..<count).map { calendar.date(byAdding: .day, value: $0, to: month) }
        slots += Array(repeating: nil, count: (7 - slots.count % 7) % 7)
        return stride(from: 0, to: slots.count, by: 7).map { Array(slots[$0..<$0 + 7]) }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                navButton("chevron.left", "Previous month") { shift(-1) }
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(HH.font(14, .bold))
                    .foregroundStyle(HH.ink)
                Spacer()
                navButton("chevron.right", "Next month") { shift(1) }
                    .disabled(!canGoForward)
                    .opacity(canGoForward ? 1 : 0.35)
            }

            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(HH.font(11, .semibold))
                        .foregroundStyle(HH.muted)
                        .frame(width: 34)
                }
            }

            VStack(spacing: 2) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 0) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                            if let day {
                                dayButton(day)
                            } else {
                                Color.clear.frame(width: 34, height: 32)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 262)
        .background(HH.surface)
    }

    private func navButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
        }
        .buttonStyle(.hh(.plain, small: true, square: true))
        .accessibilityLabel(label)
    }

    private func dayButton(_ day: Date) -> some View {
        let selected = calendar.isDate(day, inSameDayAs: selection)
        let today = calendar.isDateInToday(day)
        let blocked = max.map { day > $0 && !calendar.isDate(day, inSameDayAs: $0) } ?? false
        return Button {
            selection = day
        } label: {
            Text("\(calendar.component(.day, from: day))")
                .font(HH.font(13, selected || today ? .bold : .medium))
                .monospacedDigit()
                .foregroundStyle(selected ? HH.onPrimary : (blocked ? HH.muted.opacity(0.4) : HH.ink))
                .frame(width: 30, height: 30)
                .background(Circle().fill(selected ? HH.primary : Color.clear))
                .overlay(Circle().stroke(today && !selected ? HH.primary : Color.clear, lineWidth: 1.5))
                .frame(width: 34, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(blocked)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func shift(_ offset: Int) {
        month = calendar.date(byAdding: .month, value: offset, to: month)!
    }
}

/// A date field: the day in a box that opens a calendar.
struct HHDatePicker: View {
    @Binding var date: Date
    var max: Date?

    @State private var open = false

    var body: some View {
        Button {
            open.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar").font(.system(size: 12, weight: .medium)).foregroundStyle(HH.muted)
                Text(date.formatted(date: .long, time: .omitted))
                    .font(HH.font(14))
                    .foregroundStyle(HH.ink)
                Spacer(minLength: 12)
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(HH.muted)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(RoundedRectangle(cornerRadius: 10).fill(HH.surface))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(HH.borderStrong, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $open, arrowEdge: .bottom) {
            HHCalendarPanel(selection: Binding(get: { date }, set: { date = $0; open = false }), max: max)
        }
        .accessibilityLabel("Applied on \(date.formatted(date: .long, time: .omitted))")
    }
}
