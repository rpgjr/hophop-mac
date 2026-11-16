import Foundation
import Observation

enum Page: Hashable {
    case home
    case day(Date)
    case settings
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
    case mapping(SiteMappingGroup?)
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

    private let api = APIClient()

    /// Statuses and saved site mappings. Applications load per page, with loadApplications.
    func load() async {
        do {
            async let loadedStatuses = api.statuses()
            async let loadedMappings = api.mappings()
            statuses = try await loadedStatuses
            siteMappings = try await loadedMappings
        } catch {
            errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Returns an error message to show in the form, or nil when saved.
    func add(_ new: NewApplication) async -> String? {
        do {
            let created = try await api.createApplication(new)
            applications.append(created)
            applications.sort { $0.id < $1.id }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func setStatus(_ entry: ApplicationEntry, to status: Status) async {
        do {
            let updated = try await api.updateStatus(id: entry.id, statusId: status.id)
            if let index = applications.firstIndex(where: { $0.id == updated.id }) {
                applications[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ entry: ApplicationEntry) async {
        do {
            try await api.deleteApplication(id: entry.id)
            applications.removeAll { $0.id == entry.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Link import and site mappings

    func inspect(url: String) async throws -> InspectResult {
        try await api.inspect(url: url)
    }

    func suggest(candidates: [Candidate]) async throws -> [MappingEntry] {
        try await api.suggest(candidates: candidates)
    }

    func suggest(url: String) async throws -> [MappingEntry] {
        try await api.suggest(url: url)
    }

    /// Returns an error message to show in the editor, or nil when saved.
    func saveMapping(host: String, entries: [MappingEntry], exists: Bool) async -> String? {
        do {
            try await api.saveMapping(host: host, entries: entries, exists: exists)
            siteMappings = try await api.mappings()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func deleteMapping(_ group: SiteMappingGroup) async {
        do {
            try await api.deleteMapping(host: group.host)
            siteMappings.removeAll { $0.host == group.host }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
