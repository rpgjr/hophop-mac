import Foundation
import Observation

enum SettingsSection: String, Hashable {
    case general = "General"
    case statuses = "Statuses"
    case metaTags = "Meta tags"
}

enum Page: Hashable {
    case home
    case all
    case day(Date)
    case settings(SettingsSection)
}

struct Confirmation {
    let title: String
    let message: String
    let confirmLabel: String
    let action: () -> Void
}

/// The dialog shown over the page. HopHop draws its own instead of using system sheets.
enum Modal {
    case addJob(Date)
    case viewJob(ApplicationEntry)
    case mapping(SiteMappingGroup?)
    case status(Status?)
    case confirm(Confirmation)
}

@MainActor
@Observable
final class ApplicationStore {
    var applications: [ApplicationEntry] = []
    var statuses: [Status] = []
    var siteMappings: [SiteMappingGroup] = []
    var isLoading = false
    var errorMessage: String?
    var page: Page = .home
    var modal: Modal?

    private var api = APIClient()
    var isSignedIn = false

    /// Statuses and saved site mappings. Applications load per page, with loadApplications.
    func load() async {
        do {
            async let loadedStatuses = api.statuses()
            async let loadedMappings = api.mappings()
            statuses = try await loadedStatuses
            siteMappings = try await loadedMappings
        } catch {
            report(error)
        }
    }

    func loadApplications(from: Date, to: Date) async {
        isLoading = true
        defer { isLoading = false }
        do {
            applications = try await api.applications(from: from, to: to)
                .sorted { $0.id < $1.id }
        } catch {
            if !(error is CancellationError) && (error as? URLError)?.code != .cancelled {
                report(error)
            }
        }
    }

    /// Every application ever saved, for the CSV export.
    func allApplications() async throws -> [ApplicationEntry] {
        let first = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1))!
        let last = Calendar.current.date(from: DateComponents(year: 2099, month: 12, day: 31))!
        return try await guarded { try await api.applications(from: first, to: last) }
    }

    /// Returns an error message to show in the form, or nil when saved.
    func add(_ new: NewApplication) async -> String? {
        do {
            let created = try await api.createApplication(new)
            applications.append(created)
            applications.sort { $0.id < $1.id }
            return nil
        } catch {
            return message(for: error)
        }
    }

    /// Returns an error message to show in the form, or nil when saved.
    func update(_ entry: ApplicationEntry, with new: NewApplication) async -> String? {
        do {
            let updated = try await api.updateApplication(id: entry.id, new)
            if case .day(let shown) = page, APIClient.day(shown) != updated.appliedDate {
                applications.removeAll { $0.id == updated.id } // moved to another day
            } else if let index = applications.firstIndex(where: { $0.id == updated.id }) {
                applications[index] = updated
            }
            return nil
        } catch {
            return message(for: error)
        }
    }

    func setStatus(_ entry: ApplicationEntry, to status: Status) async {
        do {
            let updated = try await api.updateStatus(id: entry.id, statusId: status.id)
            if let index = applications.firstIndex(where: { $0.id == updated.id }) {
                applications[index] = updated
            }
        } catch {
            report(error)
        }
    }

    func delete(_ entry: ApplicationEntry) async {
        do {
            try await api.deleteApplication(id: entry.id)
            applications.removeAll { $0.id == entry.id }
        } catch {
            report(error)
        }
    }

    // MARK: - Link import and site mappings

    func inspect(url: String) async throws -> InspectResult {
        try await guarded { try await api.inspect(url: url) }
    }

    func suggest(candidates: [Candidate]) async throws -> [MappingEntry] {
        try await guarded { try await api.suggest(candidates: candidates) }
    }

    func suggest(url: String) async throws -> [MappingEntry] {
        try await guarded { try await api.suggest(url: url) }
    }

    /// Returns an error message to show in the editor, or nil when saved.
    func saveMapping(host: String, entries: [MappingEntry], exists: Bool) async -> String? {
        do {
            try await api.saveMapping(host: host, entries: entries, exists: exists)
            siteMappings = try await api.mappings()
            return nil
        } catch {
            return message(for: error)
        }
    }

    func deleteMapping(_ group: SiteMappingGroup) async {
        do {
            try await api.deleteMapping(host: group.host)
            siteMappings.removeAll { $0.host == group.host }
        } catch {
            report(error)
        }
    }

    // MARK: - Statuses

    /// Returns an error message to show in the editor, or nil when saved.
    func saveStatus(id: Int?, name: String, color: String) async -> String? {
        do {
            try await api.saveStatus(id: id, name: name, color: color)
            statuses = try await api.statuses()
            // cards on screen carry their own copy of the status, so refresh them
            if case .day(let shown) = page { await loadApplications(from: shown, to: shown) }
            return nil
        } catch APIError.badStatus(let code, _) where code == 409 {
            return "A status with that name already exists."
        } catch APIError.badStatus(let code, _) where code == 400 {
            return "Enter a name of up to 50 characters."
        } catch {
            return message(for: error)
        }
    }

    /// Moves one status to a new place and saves the whole order.
    func moveStatus(from: Int, to: Int) async {
        guard from != to, statuses.indices.contains(from), statuses.indices.contains(to) else { return }
        let before = statuses
        statuses.insert(statuses.remove(at: from), at: to)
        do {
            try await api.reorderStatuses(ids: statuses.map(\.id))
        } catch {
            statuses = before
            report(error)
        }
    }

    func deleteStatus(_ status: Status) async {
        do {
            try await api.deleteStatus(id: status.id)
            statuses.removeAll { $0.id == status.id }
        } catch APIError.badStatus(let code, _) where code == 409 {
            errorMessage = "\"\(status.name)\" cannot be removed: applications still use it, or it is your only status. Move them to another status first."
        } catch {
            report(error)
        }
    }

    // MARK: - Sign-in

    /// Returns an error message to show on the sign-in screen, or nil when signed in.
    func signIn(code: String) async -> String? {
        do {
            api.token = try await api.login(code: code)
            isSignedIn = true
            await load()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Ends the session here and tells the server to forget it.
    func signOut() {
        let closing = api
        Task { try? await closing.logout() }
        endSession()
    }

    private func endSession() {
        api.token = nil
        isSignedIn = false
        applications = []
        siteMappings = []
        statuses = []
        modal = nil
        page = .home
    }

    /// A refused session sends the user back to sign-in. Other errors show in the alert.
    private func report(_ error: Error) {
        if case APIError.unauthorized = error {
            endSession()
        } else if !(error is CancellationError), (error as? URLError)?.code != .cancelled {
            errorMessage = error.localizedDescription
        }
    }

    private func message(for error: Error) -> String {
        if case APIError.unauthorized = error { endSession() }
        return error.localizedDescription
    }

    private func guarded<T>(_ work: () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch {
            if case APIError.unauthorized = error { endSession() }
            throw error
        }
    }
}
