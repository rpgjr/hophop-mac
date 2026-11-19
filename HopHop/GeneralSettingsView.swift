import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct GeneralSettingsView: View {
    @Environment(ApplicationStore.self) private var store

    @AppStorage("hophop-theme") private var theme = ""
    @AppStorage(AppSettings.defaultStatus) private var defaultStatus = 0
    @AppStorage(AppSettings.defaultCurrency) private var currency = "PHP"
    @AppStorage(AppSettings.defaultSetup) private var setup = "Onsite"
    @AppStorage(AppSettings.defaultEmployment) private var employment = ""
    @AppStorage(AppSettings.weekStart) private var weekStart = 0

    @State private var exporting = false
    @State private var exportNote: (tone: HHNotice.Tone, text: String)?

    var body: some View {
        VStack(spacing: 16) {
            card("Appearance", icon: "paintpalette") {
                row("Theme", hint: "The colours HopHop uses on this device.") {
                    HHChoice(
                        label: "Theme",
                        selection: $theme,
                        options: [
                            .init(value: "", title: "Follow system"),
                            .init(value: "light", title: "Light"),
                            .init(value: "dark", title: "Dark"),
                        ],
                        showsLabel: false
                    )
                }
            }

            card("New applications", icon: "plus.square.on.square", hint: "What the Add form starts with. You can still change everything before saving.") {
                row("Status") {
                    HHChoice(
                        label: "Status",
                        selection: $defaultStatus,
                        options: [.init(value: 0, title: "First in the list")]
                            + store.statuses.map { .init(value: $0.id, title: $0.name, color: Color(hex: $0.color)) },
                        showsLabel: false
                    )
                }
                divider
                row("Currency") {
                    HHChoice(
                        label: "Currency",
                        selection: $currency,
                        options: JobOptions.currencies.map { .init(value: $0, title: $0) },
                        showsLabel: false
                    )
                }
                divider
                row("Setup") {
                    HHChoice(
                        label: "Setup",
                        selection: $setup,
                        options: JobOptions.setups.map { .init(value: $0, title: $0) },
                        showsLabel: false
                    )
                }
                divider
                row("Employment") {
                    HHChoice(
                        label: "Employment",
                        selection: $employment,
                        options: [.init(value: "", title: "Not specified")]
                            + JobOptions.employmentTypes.map { .init(value: $0, title: $0) },
                        showsLabel: false
                    )
                }
            }

            card("Calendar", icon: "calendar") {
                row("Week starts on", hint: "The first column of the month view.") {
                    HHChoice(
                        label: "Week starts on",
                        selection: $weekStart,
                        options: [.init(value: 0, title: "Sunday"), .init(value: 1, title: "Monday")],
                        showsLabel: false
                    )
                }
            }

            card("Data and session", icon: "externaldrive") {
                row("Export applications", hint: "Every application as a spreadsheet file for Excel or Numbers.") {
                    HStack(spacing: 12) {
                        if let exportNote {
                            HHNotice(tone: exportNote.tone, text: exportNote.text)
                        }
                        Button {
                            Task { await exportCSV() }
                        } label: {
                            if exporting {
                                HHSpinner()
                            } else {
                                Label("Export CSV", systemImage: "square.and.arrow.down")
                            }
                        }
                        .buttonStyle(.hh)
                        .disabled(exporting)
                    }
                }
                divider
                row("Lock now", hint: "You are signed out after a while without activity. This ends the session now.") {
                    Button {
                        store.signOut()
                    } label: {
                        Label("Lock", systemImage: "lock")
                    }
                    .buttonStyle(.hh(.danger))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Layout

    private var divider: some View {
        Rectangle().fill(HH.border).frame(height: 1)
    }

    /// A titled group of rows with a small icon, like a page in a system preferences window.
    private func card<Content: View>(_ title: String, icon: String, hint: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HH.primaryInk)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 8).fill(HH.primarySoft))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(HH.display(16))
                        .foregroundStyle(HH.ink)
                    if let hint {
                        Text(hint)
                            .font(HH.font(13))
                            .foregroundStyle(HH.muted)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            divider
            VStack(spacing: 0) { content() }
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hhCard()
    }

    /// The name and a short note on the left, the control on the right.
    private func row<Control: View>(_ title: String, hint: String? = nil, @ViewBuilder control: () -> Control) -> some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(HH.font(14, .medium))
                    .foregroundStyle(HH.ink)
                if let hint {
                    Text(hint)
                        .font(HH.font(12))
                        .foregroundStyle(HH.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: 230, alignment: .leading)

            control()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 14)
    }

    // MARK: - Export

    private func exportCSV() async {
        exporting = true
        exportNote = nil
        defer { exporting = false }
        do {
            let all = try await store.allApplications()
            let panel = NSSavePanel()
            panel.nameFieldStringValue = "hophop-applications-\(APIClient.day(.now)).csv"
            panel.allowedContentTypes = [.commaSeparatedText]
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try Self.csv(all).write(to: url, atomically: true, encoding: .utf8)
            exportNote = (.ok, "Saved \(all.count) applications.")
        } catch {
            exportNote = (.error, error.localizedDescription)
        }
    }

    private static func csv(_ rows: [ApplicationEntry]) -> String {
        func cell(_ value: String?) -> String {
            let text = value ?? ""
            guard text.contains(where: { ",\"\n\r".contains($0) }) else { return text }
            return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        func number(_ value: Double?) -> String? { value.map { String(format: "%g", $0) } }

        let header = ["Applied on", "Title", "Company", "Status", "Salary min", "Salary max", "Currency",
                      "Setup", "Employment", "Link", "Remarks", "Description"]
        var lines = [header.joined(separator: ",")]
        for row in rows {
            let description = row.description.map { HTMLText.plain($0) }
            let cells: [String?] = [row.appliedDate, row.title, row.company, row.status.name,
                                    number(row.salaryMin), number(row.salaryMax), row.salaryCurrency,
                                    row.setup, row.employmentType, row.link, row.remarks, description]
            lines.append(cells.map(cell).joined(separator: ","))
        }
        return "\u{FEFF}" + lines.joined(separator: "\n")
    }
}
