import SwiftUI

struct ContentView: View {
    @Environment(ApplicationStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("hophop-theme") private var themeChoice = ""

    private var preferredScheme: ColorScheme? {
        switch themeChoice {
        case "dark": .dark
        case "light": .light
        default: nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(HH.border).frame(height: 1)
            if store.isSignedIn {
                page
            } else {
                LoginView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HH.bg.ignoresSafeArea())
        .overlay { modalLayer }
        .preferredColorScheme(preferredScheme)
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .frame(minWidth: 980, minHeight: 720)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                store.page = .home
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "hare.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HH.onPrimary)
                        .frame(width: 30, height: 30)
                        .background(RoundedRectangle(cornerRadius: 8).fill(HH.primary))
                    Text("HopHop")
                        .font(HH.display(18))
                        .foregroundStyle(HH.ink)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("HopHop home")

            Spacer()

            if store.isSignedIn {
                navButton("Calendar", icon: "calendar", active: store.page != .settings) {
                    store.page = .home
                }
                navButton("Settings", icon: "slider.horizontal.3", active: store.page == .settings) {
                    store.page = .settings
                }
            }

            Button {
                themeChoice = colorScheme == .dark ? "light" : "dark"
            } label: {
                Label(colorScheme == .dark ? "Light" : "Dark",
                      systemImage: colorScheme == .dark ? "sun.max" : "moon")
            }
            .buttonStyle(.hh(.plain, small: true))
            .accessibilityLabel(colorScheme == .dark ? "Switch to light theme" : "Switch to dark theme")

            if store.isSignedIn {
                Button {
                    store.signOut()
                } label: {
                    Label("Lock", systemImage: "lock")
                }
                .buttonStyle(.hh(.plain, small: true))
                .help("Sign out")
            }
        }
        .padding(.leading, 84) // room for the window buttons
        .padding(.trailing, 20)
        .padding(.vertical, 10)
        .background(HH.surface)
    }

    private func navButton(_ title: String, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HHChip(title: title, on: active, icon: icon)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    // MARK: - Pages

    @ViewBuilder
    private var page: some View {
        switch store.page {
        case .home:
            CalendarView()
        case .day(let date):
            DayView(date: date)
        case .settings:
            SettingsView()
        }
    }

    // MARK: - Dialogs

    @ViewBuilder
    private var modalLayer: some View {
        if let modal = store.modal {
            ZStack {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture { store.modal = nil }

                switch modal {
                case .addJob(let date):
                    AddApplicationView(appliedDate: date)
                case .mapping(let group):
                    MappingEditorView(group: group)
                case .confirm(let confirmation):
                    ConfirmView(confirmation: confirmation)
                }
            }
            .onExitCommand { store.modal = nil }
            .transition(.opacity)
        }
    }
}

private struct ConfirmView: View {
    @Environment(ApplicationStore.self) private var store
    let confirmation: Confirmation

    var body: some View {
        HHModal(title: confirmation.title, subtitle: confirmation.message, width: 440) {
            EmptyView()
        } footer: {
            Button("Cancel") { store.modal = nil }
                .buttonStyle(.hh)
            Button(confirmation.confirmLabel) {
                store.modal = nil
                confirmation.action()
            }
            .buttonStyle(.hh(.danger))
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
