import SwiftUI

struct SettingsView: View {
    let section: SettingsSection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(section.rawValue)
                    .font(HH.display(26))
                    .foregroundStyle(HH.ink)

                switch section {
                case .general:
                    GeneralSettingsView()
                case .statuses:
                    StatusesView()
                case .metaTags:
                    MappingsView()
                }
            }
            .frame(maxWidth: 1240, alignment: .leading)
            .padding(.horizontal, 30)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
        }
    }
}
