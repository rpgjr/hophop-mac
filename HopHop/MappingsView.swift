import SwiftUI

struct MappingsView: View {
    @Environment(ApplicationStore.self) private var store

    private let columns = [GridItem(.adaptive(minimum: 380), spacing: 22, alignment: .top)]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Text("Tell HopHop which tag on a website holds the job title, company, salary and so on. A website can have several mappings, for example one per country. The mapping name is shown as the website on each application.")
                    .font(HH.font(14))
                    .foregroundStyle(HH.muted)
                    .frame(maxWidth: 520, alignment: .leading)
                Spacer()
                Button {
                    store.modal = .mapping(nil)
                } label: {
                    Label("Add mapping", systemImage: "plus.circle")
                }
                .buttonStyle(.hh(.primary))
            }

            if store.siteMappings.isEmpty {
                VStack(spacing: 4) {
                    Text("No mappings saved yet")
                        .font(HH.font(18, .bold))
                    Text("Press Add mapping and paste one job link.")
                        .font(HH.font(14))
                        .foregroundStyle(HH.muted)
                }
                .foregroundStyle(HH.ink)
                .frame(maxWidth: .infinity)
                .padding(32)
                .hhCard()
            } else {
                LazyVGrid(columns: columns, spacing: 22) {
                    ForEach(store.siteMappings) { group in
                        card(group)
                    }
                }
            }
        }
    }

    private func card(_ group: SiteMappingGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(group.name)
                        .font(HH.font(16, .bold))
                        .foregroundStyle(HH.ink)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text(group.host)
                            .font(HH.mono(11))
                            .foregroundStyle(HH.muted)
                            .lineLimit(1)
                        if let country = group.country {
                            Text(country)
                                .font(HH.font(11, .bold))
                                .foregroundStyle(HH.ink)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(HH.surface))
                                .overlay(Capsule().stroke(HH.border, lineWidth: 1))
                        }
                    }
                }
                Spacer()
                Button {
                    store.modal = .mapping(group)
                } label: {
                    Image(systemName: "pencil").font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.hh(.plain, square: true))
                .accessibilityLabel("Edit \(group.name)")

                Button {
                    store.modal = .confirm(Confirmation(
                        title: "Remove this mapping?",
                        message: "\(group.name) will no longer fill the form from its links. Applications keep their website name.",
                        confirmLabel: "Remove"
                    ) {
                        Task { await store.deleteMapping(group) }
                    })
                } label: {
                    Image(systemName: "trash").font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.hh(.danger, square: true))
                .accessibilityLabel("Remove \(group.name)")
            }

            VStack(alignment: .leading, spacing: 7) {
                ForEach(group.mappings.filter { $0.field != .remarks }, id: \.field) { mapping in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(mapping.field.label)
                            .font(HH.font(13, .bold))
                            .foregroundStyle(HH.ink)
                            .frame(width: 118, alignment: .leading)
                        Text(sourceName(mapping.sourceType))
                            .font(HH.font(10, .bold))
                            .foregroundStyle(HH.ink)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(HH.surface))
                            .overlay(Capsule().stroke(HH.border, lineWidth: 1))
                        Text(mapping.sourceKey)
                            .font(HH.mono(11))
                            .foregroundStyle(HH.muted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
        }
        .padding(18)
        .hhCard()
    }

    private func sourceName(_ type: String) -> String {
        switch type {
        case "META": "meta"
        case "JSON_LD": "json-ld"
        case "CSS": "element"
        case "PATTERN": "text"
        default: type.lowercased()
        }
    }
}
