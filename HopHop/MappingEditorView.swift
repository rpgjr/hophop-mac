import SwiftUI

private struct Pick: Hashable {
    let type: String
    let key: String
}

struct MappingEditorView: View {
    @Environment(ApplicationStore.self) private var store

    let group: SiteMappingGroup?

    @State private var host: String
    @State private var exists: Bool
    @State private var sampleLink = ""
    @State private var candidates: [Candidate] = []
    @State private var picks: [MappingField: Pick]
    @State private var busy: Busy?
    @State private var errorText: String?
    @State private var note: (tone: HHNotice.Tone, text: String)?
    @State private var showBrowser = false
    @State private var suggestAfterBrowser = false
    @State private var openField: MappingField?
    @State private var filter = ""

    private enum Busy { case finding, suggesting, saving }

    init(group: SiteMappingGroup?) {
        self.group = group
        _host = State(initialValue: group?.host ?? "")
        _exists = State(initialValue: group != nil)
        _picks = State(initialValue: Dictionary(
            uniqueKeysWithValues: (group?.mappings ?? []).filter { $0.field != .remarks }.map {
                ($0.field, Pick(type: $0.sourceType, key: $0.sourceKey))
            }
        ))
    }

    private var linkIsValid: Bool {
        guard let url = URL(string: sampleLink.trimmingCharacters(in: .whitespaces)),
              let scheme = url.scheme?.lowercased() else { return false }
        return ["http", "https"].contains(scheme) && url.host() != nil
    }

    var body: some View {
        HHModal(
            title: group == nil ? "Add website" : "Edit \(group!.host)",
            subtitle: "Paste any one job link from the website. HopHop lists its tags and you pick which tag fills each field. Use Suggest with AI to pick for you.",
            width: 680
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .bottom, spacing: 10) {
                    HHTextField(
                        label: "Sample job link",
                        text: $sampleLink,
                        prompt: "https://… a job link from this website"
                    )
                    Button {
                        Task { await findTags() }
                    } label: {
                        Label("Find tags", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.hh)
                    .disabled(!linkIsValid || busy != nil)
                    Button {
                        Task { await suggest() }
                    } label: {
                        Label("Suggest with AI", systemImage: "sparkles")
                    }
                    .buttonStyle(.hh(.secondary))
                    .disabled(!linkIsValid || busy != nil)
                }

                if busy == .finding || busy == .suggesting {
                    HStack(spacing: 10) {
                        HHSpinner()
                        Text("Reading the page. The server may be waking up.")
                            .font(HH.font(13, .semibold))
                            .foregroundStyle(HH.ink)
                    }
                }

                if let note {
                    HHNotice(tone: note.tone, text: note.text)
                }

                if !host.isEmpty {
                    HStack(spacing: 6) {
                        Text("Website:").font(HH.font(14))
                        Text(host).font(HH.mono(14, .bold))
                    }
                    .foregroundStyle(HH.ink)
                }

                VStack(spacing: 0) {
                    ForEach(MappingField.mappable) { field in
                        fieldRow(field)
                        if field != MappingField.mappable.last {
                            Rectangle().fill(HH.border).frame(height: 1)
                        }
                    }
                }
                .hhSunken()
            }
        } footer: {
            if let errorText {
                Text(errorText)
                    .font(HH.font(13, .bold))
                    .foregroundStyle(HH.danger)
                    .lineLimit(2)
            }
            Spacer()
            Button("Cancel") { store.modal = nil }
                .buttonStyle(.hh)
            Button {
                Task { await save() }
            } label: {
                if busy == .saving { HHSpinner() } else { Text("Save mapping") }
            }
            .buttonStyle(.hh(.primary))
            .disabled(host.isEmpty || picks.isEmpty || busy != nil)
        }
        .sheet(isPresented: $showBrowser) {
            if let url = URL(string: sampleLink.trimmingCharacters(in: .whitespaces)) {
                BrowserReaderSheet(url: url) { page in
                    Task { await finishBrowser(page) }
                }
            }
        }
    }

    // MARK: - One field and its tag list

    private func fieldRow(_ field: MappingField) -> some View {
        let pick = picks[field]
        let isOpen = openField == field
        let sample = pick.flatMap { pick in
            candidates.first { $0.type == pick.type && $0.key == pick.key }?.value
        }

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 14) {
                Text(field.label)
                    .font(HH.font(14, .bold))
                    .foregroundStyle(HH.ink)
                    .frame(width: 130, alignment: .leading)
                    .padding(.top, 9)

                VStack(alignment: .leading, spacing: 3) {
                    Button {
                        withAnimation(.easeOut(duration: 0.12)) {
                            openField = isOpen ? nil : field
                            filter = ""
                        }
                    } label: {
                        HStack {
                            Text(pick?.key ?? "Not mapped")
                                .font(HH.mono(13))
                                .opacity(pick == nil ? 0.6 : 1)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 8)
                            Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .heavy))
                        }
                        .foregroundStyle(HH.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 12).fill(HH.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(HH.borderStrong, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Tag for \(field.label)")

                    if let sample {
                        Text("e.g. \(sample)")
                            .font(HH.font(12))
                            .foregroundStyle(HH.muted)
                            .lineLimit(1)
                    }
                }
            }

            if isOpen {
                tagList(for: field)
                    .padding(.leading, 144)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func tagList(for field: MappingField) -> some View {
        let query = filter.trimmingCharacters(in: .whitespaces).lowercased()
        let shown = candidates.filter {
            query.isEmpty || $0.key.lowercased().contains(query) || $0.value.lowercased().contains(query)
        }
        let groups: [(title: String, type: String)] = [
            ("Page text", "PATTERN"), ("Page elements", "CSS"), ("Page tags", "META"), ("Job data", "JSON_LD"),
        ]

        return VStack(alignment: .leading, spacing: 8) {
            HHTextField(label: "Filter tags", text: $filter, prompt: "Type to filter")

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    tagButton(title: "Not mapped", detail: nil, selected: picks[field] == nil) {
                        picks[field] = nil
                        openField = nil
                    }
                    if candidates.isEmpty {
                        Text("Press Find tags first to list the tags on the page.")
                            .font(HH.font(12))
                            .foregroundStyle(HH.muted)
                            .padding(.vertical, 6)
                    }
                    ForEach(groups, id: \.type) { group in
                        let items = shown.filter { $0.type == group.type }
                        if !items.isEmpty {
                            HHLabel(text: group.title)
                                .padding(.top, 6)
                            ForEach(items) { candidate in
                                tagButton(
                                    title: candidate.key,
                                    detail: candidate.value,
                                    selected: picks[field] == Pick(type: candidate.type, key: candidate.key)
                                ) {
                                    picks[field] = Pick(type: candidate.type, key: candidate.key)
                                    openField = nil
                                }
                            }
                        }
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 230)
            .background(RoundedRectangle(cornerRadius: 12).fill(HH.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(HH.borderStrong, lineWidth: 1))
        }
    }

    private func tagButton(title: String, detail: String?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(HH.mono(12, .bold))
                        .foregroundStyle(HH.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let detail {
                        Text(detail)
                            .font(HH.font(12))
                            .foregroundStyle(HH.muted)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(HH.ink)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(selected ? HH.primary.opacity(0.5) : Color.clear))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// Returns true when tags were loaded. When the server cannot open the page, the browser opens instead.
    @discardableResult
    private func findTags(thenSuggest: Bool = false) async -> Bool {
        busy = .finding
        errorText = nil
        defer { busy = nil }
        do {
            let result = try await store.inspect(url: sampleLink.trimmingCharacters(in: .whitespaces))
            load(host: result.host, candidates: result.candidates, saved: result.mappings)
            return true
        } catch {
            suggestAfterBrowser = thenSuggest
            showBrowser = true
            return false
        }
    }

    private func finishBrowser(_ page: BrowserPage?) async {
        guard let page else {
            errorText = "Could not read that page. Check the link."
            return
        }
        let saved = store.siteMappings.first { $0.host == page.host }?.mappings ?? []
        load(host: page.host, candidates: page.candidates, saved: saved)
        if suggestAfterBrowser {
            suggestAfterBrowser = false
            await suggest()
        }
    }

    private func load(host: String, candidates: [Candidate], saved: [MappingEntry]) {
        self.host = host
        exists = exists || !saved.isEmpty || store.siteMappings.contains { $0.host == host }
        self.candidates = candidates
        if picks.isEmpty {
            for entry in saved {
                picks[entry.field] = Pick(type: entry.sourceType, key: entry.sourceKey)
            }
        }
    }

    private func suggest() async {
        if candidates.isEmpty {
            guard await findTags(thenSuggest: true) else { return }
        }
        busy = .suggesting
        errorText = nil
        note = nil
        defer { busy = nil }
        do {
            let entries = try await store.suggest(candidates: candidates).filter { $0.field != .remarks }
            if entries.isEmpty {
                note = (.warn, "AI found no matching tags on this page. Pick them by hand.")
            } else {
                // fields the AI skipped keep whatever was picked before
                for entry in entries {
                    picks[entry.field] = Pick(type: entry.sourceType, key: entry.sourceKey)
                }
                note = (.ok, "AI picked a tag for \(entries.count) fields. Check them, then press Save mapping.")
            }
        } catch APIError.badStatus(let code, _) where code == 502 || code == 503 {
            errorText = "The AI is busy right now. Try again in a moment, or pick the tags by hand."
        } catch {
            errorText = "AI suggestion failed. Pick the tags by hand."
        }
    }

    private func save() async {
        busy = .saving
        errorText = nil
        defer { busy = nil }

        let entries = MappingField.mappable.compactMap { field in
            picks[field].map { MappingEntry(field: field, sourceType: $0.type, sourceKey: $0.key) }
        }
        if let message = await store.saveMapping(host: host, entries: entries, exists: exists) {
            errorText = message
        } else {
            store.modal = nil
        }
    }
}
