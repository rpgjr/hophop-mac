import SwiftUI

struct AddApplicationView: View {
    @Environment(ApplicationStore.self) private var store

    private let appliedDate: Date

    init(appliedDate: Date = .now) {
        self.appliedDate = appliedDate
    }

    private enum Step { case link, review }

    private enum Note: Equatable {
        case none
        case working(String)
        case success(String)
        case warning(String)
    }

    @State private var step = Step.link
    @State private var note = Note.none
    @State private var missingHost: String?
    @State private var pendingMapping: PendingMapping?
    @State private var showBrowser = false
    @State private var browserPage: BrowserPage?
    @State private var suggestAfterBrowser = false
    @State private var isSavingMapping = false

    private struct PendingMapping {
        let host: String
        let entries: [MappingEntry]
    }
    @State private var importedLink = ""

    @State private var title = ""
    @State private var company = ""
    @State private var link = ""
    @State private var currency = AppSettings.currency
    @State private var salaryMin: Double?
    @State private var salaryMax: Double?
    @State private var setup = AppSettings.setup
    @State private var employmentType = AppSettings.employment
    @State private var statusID: Int?
    @State private var remarks = ""
    @State private var jobDescription = ""
    @State private var importedDescription: String? // the page's own HTML, kept while the text is untouched
    @State private var isSaving = false
    @State private var serverError: String?

    private var trimmedLink: String { link.trimmingCharacters(in: .whitespaces) }

    private var linkIsValid: Bool {
        guard let url = URL(string: trimmedLink),
              let scheme = url.scheme?.lowercased() else { return false }
        return ["http", "https"].contains(scheme) && url.host() != nil
    }

    private var isWorking: Bool {
        if case .working = note { return true }
        return false
    }

    private var salaryIsValid: Bool {
        guard let high = salaryMax else { return true }
        guard let low = salaryMin else { return false }
        return high >= low
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !company.trimmingCharacters(in: .whitespaces).isEmpty
            && linkIsValid && salaryIsValid && statusID != nil && !isSaving
    }

    var body: some View {
        Group {
            switch step {
            case .link: linkStep
            case .review: reviewStep
            }
        }
        .sheet(isPresented: $showBrowser) {
            if let url = URL(string: trimmedLink) {
                BrowserReaderSheet(url: url) { page in
                    Task { await finishBrowser(page) }
                }
            }
        }
        .onAppear {
            let preferred = store.statuses.first { $0.id == AppSettings.status }?.id
            statusID = statusID ?? preferred ?? store.statuses.first?.id
        }
        .task(id: link) {
            guard step == .link, linkIsValid, trimmedLink != importedLink else { return }
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            await fetchDetails()
        }
    }

    // MARK: - Step 1: only the link

    private var linkStep: some View {
        HHModal(
            title: "Add a job",
            subtitle: "Paste the job link. HopHop reads the page with the mapping saved for that website and shows the details. You check them before saving.",
            width: 520
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HHTextField(
                    label: "Job link",
                    text: $link,
                    prompt: "https://…",
                    hint: !link.isEmpty && !linkIsValid ? "Enter a full http or https link." : nil,
                    onSubmit: { Task { await fetchDetails() } }
                )
                noteView
            }
        } footer: {
            Button("Fill in by hand") { step = .review }
                .buttonStyle(.plain)
                .font(HH.font(13, .semibold))
                .underline()
                .foregroundStyle(HH.ink)
            Spacer()
            Button("Cancel") { store.modal = nil }
                .buttonStyle(.hh)
            Button("Fetch details") { Task { await fetchDetails() } }
                .buttonStyle(.hh(.primary))
                .disabled(!linkIsValid || isWorking)
        }
    }

    // MARK: - Step 2: check and save

    private var reviewStep: some View {
        HHModal(title: "Check the details", subtitle: "Applied on \(appliedDate.formatted(date: .abbreviated, time: .omitted))", width: 600) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .bottom, spacing: 10) {
                    HHTextField(
                        label: "Job link",
                        text: $link,
                        prompt: "https://…",
                        hint: !link.isEmpty && !linkIsValid ? "Enter a full http or https link." : nil
                    )
                    Button {
                        Task { await fetchDetails() }
                    } label: {
                        Label("Re-fetch", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.hh)
                    .disabled(!linkIsValid || isWorking)
                    Button {
                        Task { await suggestWithAI() }
                    } label: {
                        Label("Suggest with AI", systemImage: "sparkles")
                    }
                    .buttonStyle(.hh(.secondary))
                    .disabled(!linkIsValid || isWorking)
                }

                noteView

                HHTextField(label: "Title", text: $title, prompt: "Senior iOS Engineer")
                HHTextField(label: "Company", text: $company, prompt: "Acme Inc.")

                HStack(alignment: .top, spacing: 16) {
                    HHChoice(
                        label: "Currency",
                        selection: $currency,
                        options: JobOptions.currencies.map { .init(value: $0, title: $0) }
                    )
                    .fixedSize()
                    HHNumberField(label: "Min per month", value: $salaryMin)
                    HHNumberField(
                        label: "Max per month",
                        value: $salaryMax,
                        hint: salaryIsValid ? nil : "Max must be at least the min."
                    )
                }

                HHChoice(
                    label: "Setup",
                    selection: $setup,
                    options: JobOptions.setups.map { .init(value: $0, title: $0) }
                )
                HHChoice(
                    label: "Employment",
                    selection: $employmentType,
                    options: [.init(value: nil, title: "Not specified")]
                        + JobOptions.employmentTypes.map { .init(value: Optional($0), title: $0) }
                )
                if let current = store.statuses.first(where: { $0.id == statusID }) {
                    VStack(alignment: .leading, spacing: 6) {
                        HHLabel(text: "Status")
                        StatusMenu(statuses: store.statuses, selected: current, label: "new application") { statusID = $0.id }
                    }
                }
                HHTextArea(label: "Description", text: $jobDescription, height: 140)
                HHTextArea(label: "Remarks", text: $remarks)
            }
        } footer: {
            if let serverError {
                Text(serverError)
                    .font(HH.font(13, .bold))
                    .foregroundStyle(HH.danger)
                    .lineLimit(2)
            }
            Spacer()
            Button("Back") { step = .link; note = .none }
                .buttonStyle(.hh)
            Button("Cancel") { store.modal = nil }
                .buttonStyle(.hh)
            Button {
                Task { await save() }
            } label: {
                if isSaving { HHSpinner() } else { Text("Save") }
            }
            .buttonStyle(.hh(.primary))
            .disabled(!canSave)
        }
    }

    @ViewBuilder
    private var noteView: some View {
        switch note {
        case .none:
            EmptyView()
        case .working(let text):
            HStack(spacing: 10) {
                HHSpinner()
                Text(text)
                    .font(HH.font(13, .semibold))
                    .foregroundStyle(HH.ink)
            }
        case .success(let text):
            VStack(alignment: .leading, spacing: 8) {
                HHNotice(tone: .ok, text: text)
                if let missingHost {
                    Text("No mapping for \(missingHost) yet. Not right? Press Suggest with AI.")
                        .font(HH.font(12))
                        .foregroundStyle(HH.muted)
                }
                if let pendingMapping {
                    HStack(spacing: 10) {
                        Text("Happy with it? Save this mapping so \(pendingMapping.host) fills the form by itself next time.")
                            .font(HH.font(12))
                            .foregroundStyle(HH.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            Task { await saveSuggestedMapping(pendingMapping) }
                        } label: {
                            if isSavingMapping { HHSpinner() } else { Text("Save mapping") }
                        }
                        .buttonStyle(.hh(.plain, small: true))
                        .disabled(isSavingMapping)
                    }
                }
            }
        case .warning(let text):
            HHNotice(tone: .warn, text: text)
        }
    }

    // MARK: - Reading the page

    /// Reads the page with the mapping saved for its website, then shows the review form.
    /// When the server cannot open the page, the app opens it in its own browser instead.
    private func fetchDetails() async {
        guard linkIsValid else { return }
        importedLink = trimmedLink
        missingHost = nil
        pendingMapping = nil
        note = .working("Reading the page. The server may be waking up.")

        do {
            let result = try await store.inspect(url: trimmedLink)
            show(host: result.host, candidates: result.candidates, rules: result.mappings)
        } catch {
            openBrowser(thenSuggest: false)
        }
    }

    private func openBrowser(thenSuggest: Bool) {
        suggestAfterBrowser = thenSuggest
        note = .working("Reading the job page…")
        showBrowser = true
    }

    private func finishBrowser(_ page: BrowserPage?) async {
        guard let page else {
            step = .review
            note = .warning("Could not read that page. Fill the form by hand.")
            return
        }
        browserPage = page
        let rules = store.siteMappings.first { $0.host == page.host }?.mappings ?? []
        show(host: page.host, candidates: page.candidates, rules: rules)
        if suggestAfterBrowser {
            suggestAfterBrowser = false
            await suggestWithAI()
        }
    }

    private func show(host: String, candidates: [Candidate], rules: [MappingEntry]) {
        let job = JobImporter.read(InspectResult(host: host, candidates: candidates, mappings: rules))
        apply(job)
        step = .review

        if rules.isEmpty {
            missingHost = host
            note = .success("No details filled yet.")
        } else {
            note = .success("Filled \(job.filled) field\(job.filled == 1 ? "" : "s") from \(host). Check them before saving.")
        }
    }

    /// AI picks the tag for each field on this site. The form fills from that pick, and the user can save it.
    private func suggestWithAI() async {
        guard linkIsValid else { return }
        note = .working("Asking AI to map this website…")
        missingHost = nil
        pendingMapping = nil

        let host: String
        let candidates: [Candidate]
        if let page = browserPage, page.link == trimmedLink {
            host = page.host
            candidates = page.candidates
        } else {
            do {
                let result = try await store.inspect(url: trimmedLink)
                host = result.host
                candidates = result.candidates
            } catch {
                openBrowser(thenSuggest: true)
                return
            }
        }

        do {
            let entries = try await store.suggest(candidates: candidates).filter { $0.field != .remarks }
            let job = JobImporter.read(InspectResult(host: host, candidates: candidates, mappings: entries))
            apply(job)
            pendingMapping = PendingMapping(host: host, entries: entries)
            note = .success("AI filled \(job.filled) field\(job.filled == 1 ? "" : "s") from \(host). Check them before saving.")
        } catch {
            note = .warning("AI could not map this page. Fill the form by hand.")
        }
    }

    private func saveSuggestedMapping(_ pending: PendingMapping) async {
        isSavingMapping = true
        defer { isSavingMapping = false }
        let exists = store.siteMappings.contains { $0.host == pending.host }
        if let message = await store.saveMapping(host: pending.host, entries: pending.entries, exists: exists) {
            note = .warning(message)
        } else {
            self.pendingMapping = nil
            note = .success("Mapping saved for \(pending.host).")
        }
    }

    private func apply(_ job: ImportedJob) {
        if let value = job.title { title = value }
        if let value = job.company { company = value }
        if let value = job.salaryMin { salaryMin = value }
        if let value = job.salaryMax { salaryMax = value }
        if let value = job.currency { currency = value }
        if let value = job.employmentType { employmentType = value }
        if let value = job.setup { setup = value }
        if let value = job.description {
            jobDescription = HTMLText.plain(value)
            importedDescription = value
        }
    }

    private func save() async {
        guard let statusID else { return }
        isSaving = true
        serverError = nil
        defer { isSaving = false }

        let note = remarks.trimmingCharacters(in: .whitespacesAndNewlines)
        let new = NewApplication(
            statusId: statusID,
            title: title.trimmingCharacters(in: .whitespaces),
            company: company.trimmingCharacters(in: .whitespaces),
            salaryMin: salaryMin,
            salaryMax: salaryMax,
            salaryCurrency: currency,
            employmentType: employmentType,
            setup: setup,
            remarks: note.isEmpty ? nil : note,
            description: HTMLText.keep(shown: jobDescription, original: importedDescription),
            link: trimmedLink,
            appliedDate: APIClient.day(appliedDate)
        )

        if let message = await store.add(new) {
            serverError = message
        } else {
            store.modal = nil
        }
    }
}
