import SwiftUI

/// Every application in one list, to filter and sort.
struct AllApplicationsView: View {
    @Environment(ApplicationStore.self) private var store

    private enum SortKey: String {
        case title = "Job", status = "Status", applied = "Applied", website = "Website", setup = "Setup", salary = "Salary"
    }

    @State private var entries: [ApplicationEntry] = []
    @State private var loaded = false

    @State private var query = ""
    @State private var statusIds: Set<Int> = []
    @State private var websites: Set<String> = []
    @State private var setups: Set<String> = []
    @State private var employment: Set<String> = []
    @State private var showFilters = false
    @State private var from: Date?
    @State private var to: Date?
    @State private var sortKey = SortKey.applied
    @State private var ascending = false

    private var filtering: Bool {
        !query.isEmpty || !statusIds.isEmpty || !websites.isEmpty || !setups.isEmpty || !employment.isEmpty || from != nil || to != nil
    }

    private var shown: [ApplicationEntry] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        let order = Dictionary(uniqueKeysWithValues: store.statuses.enumerated().map { ($1.id, $0) })
        let fromKey = from.map { APIClient.day($0) }
        let toKey = to.map { APIClient.day($0) }
        let direction = ascending ? 1.0 : -1.0

        let matching = entries.filter { e in
            if !needle.isEmpty, !"\(e.title) \(e.company) \(e.website ?? "") \(e.remarks ?? "")".lowercased().contains(needle) { return false }
            if !statusIds.isEmpty, !statusIds.contains(e.status.id) { return false }
            if !websites.isEmpty, !websites.contains(e.website ?? "") { return false }
            if !setups.isEmpty, !setups.contains(e.setup) { return false }
            if !employment.isEmpty, !employment.contains(e.employmentType ?? "") { return false }
            if let fromKey, e.appliedDate < fromKey { return false }
            if let toKey, e.appliedDate > toKey { return false }
            return true
        }

        return matching.sorted { a, b in
            if sortKey == .salary {
                guard let left = a.salaryMin else { return false } // no salary always goes last
                guard let right = b.salaryMin else { return true }
                if left != right { return (left - right) * direction < 0 }
                return a.id < b.id
            }
            let result: Double
            switch sortKey {
            case .title: result = Double(a.title.localizedCompare(b.title).rawValue)
            case .status: result = Double((order[a.status.id] ?? 0) - (order[b.status.id] ?? 0))
            case .website: result = Double((a.website ?? "").localizedCompare(b.website ?? "").rawValue)
            case .setup: result = Double(a.setup.localizedCompare(b.setup).rawValue)
            default: result = Double(a.appliedDate.compare(b.appliedDate).rawValue)
            }
            return result == 0 ? a.id < b.id : result * direction < 0
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All applications")
                            .font(HH.display(26))
                            .foregroundStyle(HH.ink)
                        Text(loaded ? "\(shown.count) of \(entries.count) shown" : "Loading")
                            .font(HH.font(13))
                            .foregroundStyle(HH.muted)
                    }
                    Spacer()
                    if filtering {
                        Button {
                            clear()
                        } label: {
                            Label("Clear filters", systemImage: "xmark")
                        }
                        .buttonStyle(.hh(.plain, small: true))
                    }
                }

                filters

                if !loaded {
                    HStack(spacing: 10) {
                        HHSpinner()
                        Text("Loading. The server may be waking up.")
                            .font(HH.font(14, .semibold))
                            .foregroundStyle(HH.muted)
                    }
                } else if shown.isEmpty {
                    VStack(spacing: 4) {
                        Text(entries.isEmpty ? "No applications yet" : "Nothing matches")
                            .font(HH.font(18, .bold))
                        Text(entries.isEmpty ? "Add one from the calendar." : "Try removing a filter.")
                            .font(HH.font(14))
                            .foregroundStyle(HH.muted)
                    }
                    .foregroundStyle(HH.ink)
                    .frame(maxWidth: .infinity)
                    .padding(32)
                    .hhCard()
                } else {
                    list
                }
            }
            .frame(maxWidth: 1100)
            .padding(.horizontal, 30)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
        }
        .task { await reload() }
        // an edit or removal in the dialog changes what the list should show
        .onChange(of: store.modal == nil) { _, closed in
            if closed { Task { await reload() } }
        }
    }

    // MARK: - Filters

    /// Every website name used by an application, for the filter.
    private var websiteNames: [String] {
        Array(Set(entries.compactMap { $0.website }.filter { !$0.isEmpty })).sorted { $0.localizedCompare($1) == .orderedAscending }
    }

    private var filterCount: Int {
        statusIds.count + websites.count + setups.count + employment.count + (from == nil ? 0 : 1) + (to == nil ? 0 : 1)
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                searchField
                Button {
                    showFilters.toggle()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Filters")
                        if filterCount > 0 {
                            Text("\(filterCount)")
                                .font(HH.font(11, .bold))
                                .foregroundStyle(HH.onPrimary)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Circle().fill(HH.primary))
                        }
                    }
                }
                .buttonStyle(.hh(filterCount > 0 ? .secondary : .plain))
                .accessibilityLabel("Filters")
                .popover(isPresented: $showFilters, arrowEdge: .bottom) { filterPanel }
            }

            if filterCount > 0 {
                FlowLayout(spacing: 8) {
                    ForEach(store.statuses.filter { statusIds.contains($0.id) }) { status in
                        removable(status.name, color: Color(hex: status.color)) { statusIds.remove(status.id) }
                    }
                    ForEach(websiteNames.filter { websites.contains($0) }, id: \.self) { value in
                        removable(value) { websites.remove(value) }
                    }
                    ForEach(JobOptions.setups.filter { setups.contains($0) }, id: \.self) { value in
                        removable(value) { setups.remove(value) }
                    }
                    ForEach(JobOptions.employmentTypes.filter { employment.contains($0) }, id: \.self) { value in
                        removable(value) { employment.remove(value) }
                    }
                    if let value = from { removable("From \(value.formatted(date: .abbreviated, time: .omitted))") { from = nil } }
                    if let value = to { removable("Until \(value.formatted(date: .abbreviated, time: .omitted))") { to = nil } }
                }
            }
        }
    }

    private func removable(_ title: String, color: Color? = nil, remove: @escaping () -> Void) -> some View {
        Button(action: remove) {
            HStack(spacing: 6) {
                if let color { Circle().fill(color).frame(width: 8, height: 8) }
                Text(title)
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
            }
            .font(HH.font(12, .medium))
            .foregroundStyle(HH.primaryInk)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(Capsule().fill(HH.primarySoft))
            .overlay(Capsule().stroke(HH.primary.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove filter \(title)")
    }

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            group("Status") {
                ForEach(store.statuses) { status in
                    chip(status.name, color: Color(hex: status.color), on: statusIds.contains(status.id),
                         suffix: "\(entries.filter { $0.status.id == status.id }.count)") {
                        flip(&statusIds, status.id)
                    }
                }
            }
            if !websiteNames.isEmpty {
                group("Website") {
                    ForEach(websiteNames, id: \.self) { value in
                        chip(value, on: websites.contains(value),
                             suffix: "\(entries.filter { $0.website == value }.count)") {
                            flip(&websites, value)
                        }
                    }
                }
            }
            group("Setup") {
                ForEach(JobOptions.setups, id: \.self) { value in
                    chip(value, on: setups.contains(value)) { flip(&setups, value) }
                }
            }
            group("Employment") {
                ForEach(JobOptions.employmentTypes, id: \.self) { value in
                    chip(value, on: employment.contains(value)) { flip(&employment, value) }
                }
            }
            group("Applied") {
                DateChip(title: "From", date: $from)
                DateChip(title: "To", date: $to)
            }
            if filterCount > 0 {
                Button("Clear all") { clear() }
                    .buttonStyle(.hh(.plain, small: true))
            }
        }
        .padding(18)
        .frame(width: 440, alignment: .leading)
        .background(HH.surface)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(HH.muted)
            TextField("", text: $query, prompt: Text("Search title, company, website or remarks").foregroundStyle(HH.muted.opacity(0.65)))
                .textFieldStyle(.plain)
                .font(HH.font(14))
                .foregroundStyle(HH.ink)
                .accessibilityLabel("Search applications")
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(HH.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(RoundedRectangle(cornerRadius: 10).fill(HH.surface))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(HH.borderStrong, lineWidth: 1))
    }

    private func group<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HHLabel(text: label)
            FlowLayout(spacing: 8) { content() }
        }
    }

    private func chip(_ title: String, color: Color? = nil, on: Bool, suffix: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HHChip(title: suffix.map { "\(title)  \($0)" } ?? title, color: color, on: on)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// A date limit: a chip that opens a calendar, with a clear button once a day is set.
    private struct DateChip: View {
        let title: String
        @Binding var date: Date?

        @State private var open = false

        var body: some View {
            HStack(spacing: 6) {
                Button {
                    open.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar").font(.system(size: 11, weight: .semibold))
                        Text(date.map { "\(title) \($0.formatted(date: .abbreviated, time: .omitted))" } ?? title)
                    }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $open, arrowEdge: .bottom) {
                    HHCalendarPanel(selection: Binding(get: { date ?? .now }, set: { date = $0; open = false }), max: .now)
                }
                if date != nil {
                    Button {
                        date = nil
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear \(title) date")
                }
            }
            .font(HH.font(13, .medium))
            .foregroundStyle(date == nil ? HH.ink : HH.primaryInk)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Capsule().fill(date == nil ? HH.surface : HH.primarySoft))
            .overlay(Capsule().stroke(date == nil ? HH.borderStrong : HH.primary, lineWidth: 1))
            .fixedSize()
        }
    }

    private func flip<T: Hashable>(_ set: inout Set<T>, _ value: T) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    private func clear() {
        query = ""
        statusIds = []
        websites = []
        setups = []
        employment = []
        from = nil
        to = nil
    }

    // MARK: - List

    private static let widths: [SortKey: CGFloat] = [.status: 120, .applied: 105, .website: 130, .setup: 105, .salary: 140]

    private var list: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                header(.title)
                header(.status).frame(width: Self.widths[.status])
                header(.applied).frame(width: Self.widths[.applied])
                header(.website).frame(width: Self.widths[.website])
                header(.setup).frame(width: Self.widths[.setup])
                header(.salary).frame(width: Self.widths[.salary], alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .frame(height: 38)
            Rectangle().fill(HH.border).frame(height: 1)

            LazyVStack(spacing: 0) {
                ForEach(shown) { entry in
                    Row(entry: entry, widths: Self.widths) { store.modal = .viewJob(entry) }
                    Rectangle().fill(HH.border).frame(height: 1)
                }
            }
        }
        .hhCard()
    }

    private func header(_ key: SortKey) -> some View {
        Button {
            if sortKey == key {
                ascending.toggle()
            } else {
                sortKey = key
                ascending = key != .applied
            }
        } label: {
            HStack(spacing: 4) {
                Text(key.rawValue)
                Image(systemName: sortKey == key ? (ascending ? "arrow.up" : "arrow.down") : "arrow.up.arrow.down")
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(sortKey == key ? 1 : 0.5)
            }
            .font(HH.font(12, .semibold))
            .foregroundStyle(sortKey == key ? HH.ink : HH.muted)
            .frame(maxWidth: key == .title ? .infinity : nil, alignment: key == .salary ? .trailing : .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sort by \(key.rawValue)")
    }

    private func reload() async {
        if let all = try? await store.allApplications() { entries = all }
        loaded = true
    }

    private struct Row: View {
        let entry: ApplicationEntry
        let widths: [SortKey: CGFloat]
        let open: () -> Void

        @State private var hovering = false

        var body: some View {
            Button(action: open) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title)
                            .font(HH.font(14, .semibold))
                            .foregroundStyle(HH.ink)
                            .lineLimit(1)
                        Text(entry.company)
                            .font(HH.font(13))
                            .foregroundStyle(HH.muted)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 7) {
                        Circle().fill(Color(hex: entry.status.color)).frame(width: 9, height: 9)
                        Text(entry.status.name).lineLimit(1)
                    }
                    .font(HH.font(13, .medium))
                    .foregroundStyle(HH.ink)
                    .frame(width: widths[.status], alignment: .leading)

                    Text(entry.appliedDateText)
                        .font(HH.font(13))
                        .foregroundStyle(HH.ink)
                        .frame(width: widths[.applied], alignment: .leading)

                    Text(entry.website ?? "")
                        .font(HH.font(13))
                        .foregroundStyle(HH.ink)
                        .lineLimit(1)
                        .frame(width: widths[.website], alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.setup).foregroundStyle(HH.ink)
                        if let type = entry.employmentType {
                            Text(type).foregroundStyle(HH.muted)
                        }
                    }
                    .font(HH.font(13))
                    .lineLimit(1)
                    .frame(width: widths[.setup], alignment: .leading)

                    Text(entry.salaryMin == nil ? "Salary not listed" : entry.salaryText)
                        .font(HH.font(13))
                        .foregroundStyle(HH.ink)
                        .lineLimit(1)
                        .frame(width: widths[.salary], alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(hovering ? HH.sunken : Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
        }
    }
}
