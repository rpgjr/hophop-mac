import SwiftUI

struct StatusesView: View {
    @Environment(ApplicationStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Text("The stages an application moves through. Add your own, pick a colour for each, and drag them into the order you want. That order is used in every status list.")
                    .font(HH.font(14))
                    .foregroundStyle(HH.muted)
                    .frame(maxWidth: 520, alignment: .leading)
                Spacer()
                Button {
                    store.modal = .status(nil)
                } label: {
                    Label("Add status", systemImage: "plus.circle")
                }
                .buttonStyle(.hh(.primary))
            }

            VStack(spacing: 8) {
                ForEach(Array(store.statuses.enumerated()), id: \.element.id) { index, status in
                    StatusRow(status: status, index: index, count: store.statuses.count)
                }
            }
        }
    }
}

private struct StatusRow: View {
    @Environment(ApplicationStore.self) private var store

    let status: Status
    let index: Int
    let count: Int

    @State private var dropping = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(HH.muted)
                .help("Drag to reorder")
            Circle().fill(Color(hex: status.color)).frame(width: 16, height: 16)
            Text(status.name)
                .font(HH.font(14, .medium))
                .foregroundStyle(HH.ink)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button {
                Task { await store.moveStatus(from: index, to: index - 1) }
            } label: {
                Image(systemName: "arrow.up").font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.hh(.plain, small: true, square: true))
            .disabled(index == 0)
            .help("Move up")
            .accessibilityLabel("Move \(status.name) up")
            Button {
                Task { await store.moveStatus(from: index, to: index + 1) }
            } label: {
                Image(systemName: "arrow.down").font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.hh(.plain, small: true, square: true))
            .disabled(index == count - 1)
            .help("Move down")
            .accessibilityLabel("Move \(status.name) down")
            Button {
                store.modal = .status(status)
            } label: {
                Image(systemName: "pencil").font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.hh(.plain, small: true, square: true))
            .help("Edit")
            .accessibilityLabel("Edit \(status.name)")
            Button {
                store.modal = .confirm(Confirmation(
                    title: "Remove this status?",
                    message: status.name,
                    confirmLabel: "Remove"
                ) {
                    Task { await store.deleteStatus(status) }
                })
            } label: {
                Image(systemName: "trash").font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.hh(.danger, small: true, square: true))
            .help("Remove")
            .accessibilityLabel("Remove \(status.name)")
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .hhCard()
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(HH.primary, lineWidth: dropping ? 2 : 0))
        .draggable(String(status.id))
        .dropDestination(for: String.self) { items, _ in
            guard let moved = items.first.flatMap(Int.init),
                  let from = store.statuses.firstIndex(where: { $0.id == moved }) else { return false }
            Task { await store.moveStatus(from: from, to: index) }
            return true
        } isTargeted: { dropping = $0 }
    }
}

struct StatusEditorView: View {
    @Environment(ApplicationStore.self) private var store

    let status: Status?

    @State private var name: String
    @State private var color: Color
    @State private var isSaving = false
    @State private var serverError: String?

    private static let presets = ["#3B82F6", "#F59E0B", "#10B981", "#EF4444", "#8B5CF6", "#EC4899", "#14B8A6", "#64748B"]

    init(status: Status?) {
        self.status = status
        _name = State(initialValue: status?.name ?? "")
        _color = State(initialValue: Color(hex: status?.color ?? Self.presets[0]))
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        HHModal(
            title: status == nil ? "Add status" : "Edit status",
            subtitle: "The name and colour show on every application with this status.",
            width: 480,
            scrolls: false
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HHTextField(label: "Name", text: $name, prompt: "Technical interview", onSubmit: { Task { await save() } })

                VStack(alignment: .leading, spacing: 8) {
                    HHLabel(text: "Colour")
                    HStack(spacing: 8) {
                        ForEach(Self.presets, id: \.self) { hex in
                            Button {
                                color = Color(hex: hex)
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 26, height: 26)
                                    .overlay(Circle().stroke(HH.ink, lineWidth: color.hexString.lowercased() == hex.lowercased() ? 2 : 0).padding(-3))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Use colour \(hex)")
                        }
                        ColorPicker("Any colour", selection: $color, supportsOpacity: false)
                            .font(HH.font(13))
                            .foregroundStyle(HH.muted)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HHLabel(text: "Preview")
                    HHChip(title: trimmedName.isEmpty ? "Status name" : trimmedName, color: color, tag: true)
                }
            }
        } footer: {
            if let serverError {
                Text(serverError)
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
                if isSaving { HHSpinner() } else { Text("Save") }
            }
            .buttonStyle(.hh(.primary))
            .disabled(trimmedName.isEmpty || isSaving)
        }
    }

    private func save() async {
        guard !trimmedName.isEmpty, !isSaving else { return }
        isSaving = true
        serverError = nil
        defer { isSaving = false }
        if let message = await store.saveStatus(id: status?.id, name: trimmedName, color: color.hexString) {
            serverError = message
        } else {
            store.modal = nil
        }
    }
}
