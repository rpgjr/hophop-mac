import SwiftUI

/// A status dropdown: the box shows the current status and the list shows every status with its colour.
struct StatusMenu: View {
    let statuses: [Status]
    let selected: Status
    let label: String
    let onSelect: (Status) -> Void

    var body: some View {
        HHDropdown(
            label: "Status for \(label)",
            selection: Binding(
                get: { selected.id },
                set: { id in
                    if id != selected.id, let status = statuses.first(where: { $0.id == id }) { onSelect(status) }
                }
            ),
            options: statuses.map { .init(value: $0.id, title: $0.name, color: Color(hex: $0.color)) }
        )
    }
}
