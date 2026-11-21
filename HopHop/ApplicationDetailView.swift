import SwiftUI

/// Every saved detail of one application, with an Edit button that turns them into a form.
struct ApplicationDetailView: View {
    @Environment(ApplicationStore.self) private var store
    @Environment(\.openURL) private var openURL

    let entry: ApplicationEntry

    private enum Tab: CaseIterable {
        case details, history
        var title: String { self == .details ? "Details" : "Status history" }
    }

    @State private var tab = Tab.details
    @State private var editing = false
    @State private var isSaving = false
    @State private var serverError: String?

    @State private var title: String
    @State private var company: String
    @State private var link: String
    @State private var currency: String
    @State private var salaryMin: Double?
    @State private var salaryMax: Double?
    @State private var setup: String
    @State private var employmentType: String?
    @State private var statusID: Int
    @State private var appliedDate: Date
    @State private var remarks: String
    @State private var jobDescription: String
    private let richDescription: AttributedString?

    init(entry: ApplicationEntry) {
        self.entry = entry
        _title = State(initialValue: entry.title)
        _company = State(initialValue: entry.company)
        _link = State(initialValue: entry.link)
        _currency = State(initialValue: entry.salaryCurrency)
        _salaryMin = State(initialValue: entry.salaryMin)
        _salaryMax = State(initialValue: entry.salaryMax)
        _setup = State(initialValue: entry.setup)
        _employmentType = State(initialValue: entry.employmentType)
        _statusID = State(initialValue: entry.status.id)
        _appliedDate = State(initialValue: Self.date(from: entry.appliedDate))
        _remarks = State(initialValue: entry.remarks ?? "")
        _jobDescription = State(initialValue: HTMLText.plain(entry.description ?? ""))
        richDescription = entry.description.flatMap { $0.isEmpty ? nil : HTMLText.attributed($0) }
    }

    private static func date(from day: String) -> Date {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return .now }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) ?? .now
    }

    private var trimmedLink: String { link.trimmingCharacters(in: .whitespaces) }

    private var linkIsValid: Bool {
        guard let url = URL(string: trimmedLink),
              let scheme = url.scheme?.lowercased() else { return false }
        return ["http", "https"].contains(scheme) && url.host() != nil
    }

    private var salaryIsValid: Bool {
        guard let high = salaryMax else { return true }
        guard let low = salaryMin else { return false }
        return high >= low
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !company.trimmingCharacters(in: .whitespaces).isEmpty
            && linkIsValid && salaryIsValid && !isSaving
    }

    var body: some View {
        if editing { form } else { details }
    }

    // MARK: - Read-only view

    private var details: some View {
        HHModal(title: entry.title, subtitle: entry.company, width: 580, scrolls: false) {
            VStack(alignment: .leading, spacing: 18) {
                tabBar
                if tab == .history {
                    StatusHistoryView(entry: entry)
                } else {
                    summary
                }
            }
        } footer: {
            Button {
                let target = entry
                store.modal = .confirm(Confirmation(
                    title: "Remove this application?",
                    message: "\(target.title) at \(target.company)",
                    confirmLabel: "Remove"
                ) {
                    Task { await store.delete(target) }
                })
            } label: {
                Label("Remove", systemImage: "trash")
            }
            .buttonStyle(.hh(.danger))
            Spacer()
            Button("Close") { store.modal = nil }
                .buttonStyle(.hh)
            Button {
                editing = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .buttonStyle(.hh(.primary))
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Circle().fill(Color(hex: entry.status.color)).frame(width: 9, height: 9)
                    Text(entry.status.name).font(HH.font(13, .semibold))
                }
                .foregroundStyle(HH.ink)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(Capsule().fill(HH.sunken))
                .overlay(Capsule().stroke(HH.border, lineWidth: 1))

                Label(
                    "Applied \(Self.date(from: entry.appliedDate).formatted(date: .long, time: .omitted))",
                    systemImage: "calendar"
                )
                .font(HH.font(13))
                .foregroundStyle(HH.muted)
            }

            HStack(spacing: 10) {
                fact("Salary per month", entry.salaryMin == nil ? "Not listed" : entry.salaryText)
                fact("Setup", entry.setup)
                fact("Employment", entry.employmentType ?? "Not specified")
            }

            VStack(alignment: .leading, spacing: 6) {
                HHLabel(text: "Job link")
                HStack(spacing: 8) {
                    Text(entry.link)
                        .font(HH.font(13))
                        .foregroundStyle(HH.primary)
                        .underline()
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture { open(entry.link) }
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(entry.link, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc").font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.hh(.plain, small: true, square: true))
                    .help("Copy link")
                    .accessibilityLabel("Copy job link")
                    Button { open(entry.link) } label: {
                        Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.hh(.plain, small: true, square: true))
                    .help("Open posting")
                    .accessibilityLabel("Open job posting")
                }
                .padding(.leading, 12)
                .padding(.trailing, 6)
                .frame(height: 38)
                .hhSunken(radius: 8)
            }

            if let richDescription {
                VStack(alignment: .leading, spacing: 6) {
                    HHLabel(text: "Description")
                    ScrollView {
                        Text(richDescription)
                            .font(HH.font(14))
                            .foregroundStyle(HH.ink)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .frame(maxHeight: 200)
                    .fixedSize(horizontal: false, vertical: true)
                    .hhSunken(radius: 8)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HHLabel(text: "Remarks")
                ScrollView {
                    Group {
                        if let remarks = entry.remarks, !remarks.isEmpty {
                            Text(hhLinkified(remarks)).foregroundStyle(HH.ink)
                        } else {
                            Text("No remarks yet. Press Edit to add some.").foregroundStyle(HH.muted)
                        }
                    }
                    .font(HH.font(14))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }
                .frame(maxHeight: 190)
                .fixedSize(horizontal: false, vertical: true)
                .hhSunken(radius: 8)
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { item in
                Button { tab = item } label: {
                    Text(item.title)
                        .font(HH.font(13, .semibold))
                        .foregroundStyle(tab == item ? HH.primaryInk : HH.muted)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(tab == item ? HH.primary : .clear)
                                .frame(height: 2)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
            Spacer()
        }
        .overlay(alignment: .bottom) { Rectangle().fill(HH.border).frame(height: 1) }
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HHLabel(text: label)
            Text(value)
                .font(HH.font(14, .semibold))
                .monospacedDigit()
                .foregroundStyle(HH.ink)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hhSunken(radius: 8)
    }

    private func open(_ link: String) {
        if let url = URL(string: link) { openURL(url) }
    }

    // MARK: - Edit form

    private var form: some View {
        HHModal(title: "Edit application", subtitle: entry.company, width: 600) {
            VStack(alignment: .leading, spacing: 16) {
                HHTextField(label: "Title", text: $title)
                HHTextField(label: "Company", text: $company)
                HHTextField(
                    label: "Job link",
                    text: $link,
                    prompt: "https://…",
                    hint: !link.isEmpty && !linkIsValid ? "Enter a full http or https link." : nil
                )

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
                        StatusMenu(statuses: store.statuses, selected: current, label: entry.title) { statusID = $0.id }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    HHLabel(text: "Applied on")
                    HHDatePicker(date: $appliedDate, max: .now)
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
            Button("Cancel") { editing = false; serverError = nil }
                .buttonStyle(.hh)
            Button {
                Task { await save() }
            } label: {
                if isSaving { HHSpinner() } else { Text("Save changes") }
            }
            .buttonStyle(.hh(.primary))
            .disabled(!canSave)
        }
    }

    private func save() async {
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
            description: HTMLText.keep(shown: jobDescription, original: entry.description),
            link: trimmedLink,
            appliedDate: APIClient.day(appliedDate)
        )

        if let message = await store.update(entry, with: new) {
            serverError = message
        } else {
            store.modal = nil
        }
    }
}
