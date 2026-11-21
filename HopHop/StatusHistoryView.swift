import SwiftUI

/// Every status an application has had, oldest first, one row per change.
struct StatusHistoryView: View {
    @Environment(ApplicationStore.self) private var store

    let entry: ApplicationEntry

    @State private var rows: [StatusHistoryEntry]?
    @State private var errorText: String?

    var body: some View {
        Group {
            if let errorText {
                HHNotice(tone: .error, text: errorText)
            } else if let rows {
                if rows.isEmpty {
                    Text("No status changes recorded yet.")
                        .font(HH.font(14))
                        .foregroundStyle(HH.muted)
                } else {
                    timeline(rows)
                }
            } else {
                HStack { Spacer(); HHSpinner(); Spacer() }.padding(.vertical, 24)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: entry.id) {
            do {
                rows = try await store.statusHistory(for: entry)
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private func timeline(_ rows: [StatusHistoryEntry]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle().fill(Color(hex: row.toColor)).frame(width: 11, height: 11)
                                .padding(.top, 4)
                            if index < rows.count - 1 {
                                Rectangle().fill(HH.border).frame(width: 1).frame(maxHeight: .infinity)
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(Self.dayText(row.changedAt))
                                .font(HH.font(14, .semibold))
                                .foregroundStyle(HH.ink)
                            HStack(spacing: 8) {
                                if let from = row.fromStatus {
                                    HHChip(title: from, color: Color(hex: row.fromColor ?? "#6b7280"), tag: true)
                                    Text("to").font(HH.font(13)).foregroundStyle(HH.muted)
                                } else {
                                    Text("Status").font(HH.font(13)).foregroundStyle(HH.muted)
                                }
                                HHChip(title: row.toStatus, color: Color(hex: row.toColor), tag: true)
                            }
                        }
                        .padding(.bottom, 18)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(maxHeight: 360)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// "2026-11-12T10:30:00" shown as "November 12, 2026".
    private static func dayText(_ changedAt: String) -> String {
        let parts = changedAt.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let date = Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        else { return String(changedAt.prefix(10)) }
        return date.formatted(date: .long, time: .omitted)
    }
}
