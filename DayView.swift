import SwiftUI

struct DayView: View {
    @Environment(ApplicationStore.self) private var store
    @Environment(\.openURL) private var openURL

    let date: Date

    private enum SortKey: String, CaseIterable {
        case salary = "Salary", setup = "Setup", status = "Status"
    }

    @State private var sortKey: SortKey?
    @State private var ascending = true

    private var entries: [ApplicationEntry] {
        guard let sortKey else { return store.applications }
        let direction: Double = ascending ? 1 : -1
        return store.applications.sorted { a, b in
            switch sortKey {
            case .salary:
                guard let left = a.salaryMin else { return false } // no salary always goes last
                guard let right = b.salaryMin else { return true }
                return (left - right) * direction < 0
            case .setup:
                return a.setup.localizedCompare(b.setup) == (ascending ? .orderedAscending : .orderedDescending)
            case .status:
                return a.status.name.localizedCompare(b.status.name) == (ascending ? .orderedAscending : .orderedDescending)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    store.page = .home
                } label: {
                    Label("Back to calendar", systemImage: "arrow.left")
                }
                .buttonStyle(.hh(.plain, small: true))

                HStack {
                    Text(date.formatted(date: .complete, time: .omitted))
                        .font(HH.display(26))
                        .foregroundStyle(HH.ink)
                    Spacer()
                    Button {
                        store.modal = .addJob(date)
                    } label: {
                        Label("Add Application", systemImage: "plus.circle")
                    }
                    .buttonStyle(.hh(.primary))
                    .keyboardShortcut("n")
                }

                if store.applications.count > 1 { sortBar }

                if store.isLoading && store.applications.isEmpty {
                    HStack(spacing: 10) {
                        HHSpinner()
                        Text("Loading. The server may be waking up.")
                            .font(HH.font(14, .semibold))
                            .foregroundStyle(HH.muted)
                    }
                } else if store.applications.isEmpty {
                    VStack(spacing: 4) {
                        Text("Nothing applied on this day")
                            .font(HH.font(18, .bold))
                        Text("Add a job with the button above.")
                            .font(HH.font(14))
                            .foregroundStyle(HH.muted)
                    }
                    .foregroundStyle(HH.ink)
                    .frame(maxWidth: .infinity)
                    .padding(32)
                    .hhCard()
                } else {
                    LazyVStack(spacing: 18) {
                        ForEach(entries) { entry in
                            ApplicationCard(
                                entry: entry,
                                statuses: store.statuses,
                                onStatus: { status in Task { await store.setStatus(entry, to: status) } },
                                onOpen: { if let url = URL(string: entry.link) { openURL(url) } },
                                onRemove: { confirmRemove(entry) }
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: 860)
            .padding(.horizontal, 30)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
        }
        .task(id: date) { await store.loadApplications(from: date, to: date) }
    }

    private var sortBar: some View {
        HStack(spacing: 8) {
            HHLabel(text: "Sort")
            ForEach(SortKey.allCases, id: \.self) { key in
                Button {
                    toggleSort(key)
                } label: {
                    HHChip(
                        title: key.rawValue,
                        on: sortKey == key,
                        icon: sortKey == key ? (ascending ? "arrow.up" : "arrow.down") : nil
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // click once = ascending, twice = descending, third time = no sort
    private func toggleSort(_ key: SortKey) {
        if sortKey != key {
            sortKey = key
            ascending = true
        } else if ascending {
            ascending = false
        } else {
            sortKey = nil
        }
    }

    private func confirmRemove(_ entry: ApplicationEntry) {
        store.modal = .confirm(Confirmation(
            title: "Remove this application?",
            message: "\(entry.title) at \(entry.company)",
            confirmLabel: "Remove"
        ) {
            Task { await store.delete(entry) }
        })
    }
}

// Plain values only, so a card that is being removed never reads the environment.
struct ApplicationCard: View {
    let entry: ApplicationEntry
    let statuses: [Status]
    let onStatus: (Status) -> Void
    let onOpen: () -> Void
    let onRemove: () -> Void

    @State private var picking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("#\(entry.id)")
                        .font(HH.font(11, .medium))
                        .foregroundStyle(HH.muted)
                    Text(entry.title)
                        .font(HH.display(17))
                        .foregroundStyle(HH.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(entry.company)
                        .font(HH.font(14))
                        .foregroundStyle(HH.muted)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Button {
                        withAnimation(.easeOut(duration: 0.12)) { picking.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Circle().fill(Color(hex: entry.status.color)).frame(width: 9, height: 9)
                            Text(entry.status.name)
                            Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                        }
                        .font(HH.font(13, .medium))
                        .foregroundStyle(HH.ink)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(Capsule().fill(HH.surface))
                        .overlay(Capsule().stroke(HH.borderStrong, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Status for \(entry.title): \(entry.status.name)")

                    Button(action: onOpen) {
                        Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.hh(.plain, square: true))
                    .accessibilityLabel("Open job posting for \(entry.title)")

                    Button(action: onRemove) {
                        Image(systemName: "trash").font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.hh(.danger, square: true))
                    .accessibilityLabel("Remove \(entry.title)")
                }
            }

            if picking {
                HStack(spacing: 8) {
                    ForEach(statuses) { status in
                        Button {
                            picking = false
                            if status.id != entry.status.id { onStatus(status) }
                        } label: {
                            HHChip(
                                title: status.name,
                                color: Color(hex: status.color),
                                on: status.id == entry.status.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            FlowLayout(spacing: 8) {
                HHChip(title: entry.salaryMin == nil ? "Salary not listed" : entry.salaryText, tag: true)
                HHChip(title: entry.setup, tag: true)
                if let type = entry.employmentType {
                    HHChip(title: type, tag: true)
                }
            }

            if let remarks = entry.remarks, !remarks.isEmpty {
                Text(remarks)
                    .font(HH.font(13))
                    .foregroundStyle(HH.muted)
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(HH.borderStrong).frame(width: 2)
                    }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hhCard()
    }
}
