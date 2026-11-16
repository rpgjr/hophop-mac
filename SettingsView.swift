import SwiftUI

struct SettingsView: View {
    private enum Tab: String, CaseIterable {
        case general = "General"
        case metaTags = "Meta tags"
    }

    @State private var tab = Tab.metaTags

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Settings")
                    .font(HH.display(26))
                    .foregroundStyle(HH.ink)

                HStack(spacing: 8) {
                    ForEach(Tab.allCases, id: \.self) { item in
                        Button {
                            tab = item
                        } label: {
                            HHChip(title: item.rawValue, on: tab == item)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(tab == item ? .isSelected : [])
                    }
                }

                switch tab {
                case .general:
                    Text("General settings will go here.")
                        .font(HH.font(14))
                        .foregroundStyle(HH.muted)
                case .metaTags:
                    MappingsView()
                }
            }
            .frame(maxWidth: 940, alignment: .leading)
            .padding(.horizontal, 30)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
        }
    }
}
