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
        .ignoresSafeArea(.container, edges: .top)
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

    private var onSettings: Bool {
        if case .settings = store.page { return true }
        return false
    }

    private var onAll: Bool { store.page == .all }

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                store.page = .home
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "hare.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(HH.onPrimary)
                        .frame(width: 28, height: 28)
                        .background(RoundedRectangle(cornerRadius: 8).fill(HH.primary))
                    Text("HopHop")
                        .font(HH.display(17))
                        .foregroundStyle(HH.ink)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("HopHop home")

            if store.isSignedIn {
                HStack(spacing: 4) {
                    HeaderTab(title: "Calendar", icon: "calendar", on: !onSettings && !onAll) { store.page = .home }
                    HeaderTab(title: "Applications", icon: "list.bullet", on: onAll) { store.page = .all }
                }
                .padding(.leading, 10)
            }

            Spacer()

            Button {
                themeChoice = colorScheme == .dark ? "light" : "dark"
            } label: {
                Image(systemName: colorScheme == .dark ? "sun.max" : "moon")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.hh(.plain, small: true, square: true))
            .help(colorScheme == .dark ? "Switch to light theme" : "Switch to dark theme")
            .accessibilityLabel(colorScheme == .dark ? "Switch to light theme" : "Switch to dark theme")

            if store.isSignedIn {
                SettingsMenu()
            }
        }
        // the window buttons have the strip above, so the logo and tabs sit in the left corner under them
        .padding(.leading, 18)
        .padding(.trailing, 18)
        .frame(height: 46)
        .padding(.top, 28)
        .background(HH.surface)
    }

    // MARK: - Pages

    @ViewBuilder
    private var page: some View {
        switch store.page {
        case .home:
            CalendarView()
        case .all:
            AllApplicationsView()
        case .day(let date):
            DayView(date: date)
        case .settings(let section):
            SettingsView(section: section)
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
                case .viewJob(let entry):
                    ApplicationDetailView(entry: entry)
                case .mapping(let group):
                    MappingEditorView(group: group)
                case .status(let status):
                    StatusEditorView(status: status)
                case .confirm(let confirmation):
                    ConfirmView(confirmation: confirmation)
                }
            }
            .onExitCommand { store.modal = nil }
            .transition(.opacity)
        }
    }
}

/// A page link in the bar: plain text, with a line under the page you are on.
private struct HeaderTab: View {
    let title: String
    let icon: String
    let on: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 12, weight: .medium))
                Text(title).font(HH.font(14, .semibold))
            }
            .foregroundStyle(on ? HH.primaryInk : (hovering ? HH.ink : HH.muted))
            .padding(.horizontal, 12)
            .frame(height: 46)
            .overlay(alignment: .bottom) {
                Rectangle().fill(on ? HH.primary : Color.clear).frame(height: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(on ? .isSelected : [])
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

/// The gear at the right end of the bar: its list holds the settings pages and Lock.
private struct SettingsMenu: View {
    @Environment(ApplicationStore.self) private var store
    @State private var open = false

    private var current: SettingsSection? {
        if case .settings(let section) = store.page { return section }
        return nil
    }

    var body: some View {
        Button {
            open.toggle()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 13, weight: .medium))
        }
        .buttonStyle(.hh(current != nil ? .secondary : .plain, small: true, square: true))
        .help("Settings")
        .accessibilityLabel("Settings menu")
        .popover(isPresented: $open, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                row("General", icon: "slider.horizontal.3", active: current == .general) {
                    store.page = .settings(.general)
                }
                row("Statuses", icon: "flag", active: current == .statuses) {
                    store.page = .settings(.statuses)
                }
                row("Meta tags", icon: "tag", active: current == .metaTags) {
                    store.page = .settings(.metaTags)
                }
                Rectangle().fill(HH.border).frame(height: 1).padding(.vertical, 4)
                row("Lock", icon: "lock", tint: HH.danger) {
                    store.signOut()
                }
            }
            .padding(6)
            .frame(width: 190)
            .background(HH.surface)
        }
    }

    private func row(_ title: String, icon: String, tint: Color? = nil, active: Bool = false, action: @escaping () -> Void) -> some View {
        MenuRow(title: title, icon: icon, tint: tint, active: active) {
            open = false
            action()
        }
    }
}

private struct MenuRow: View {
    let title: String
    let icon: String
    let tint: Color?
    let active: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16)
                Text(title).font(HH.font(13, .medium))
                Spacer(minLength: 0)
                if active {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                }
            }
            .foregroundStyle(tint ?? (active ? HH.primaryInk : HH.ink))
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(hovering ? (tint == nil ? HH.sunken : HH.dangerSoft) : (active ? HH.primarySoft : Color.clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}
