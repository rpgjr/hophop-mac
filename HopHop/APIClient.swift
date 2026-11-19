import Foundation

enum APIError: LocalizedError {
    case badStatus(code: Int, call: String)
    case unauthorized
    case badCode
    case tooManyAttempts
    case signInNotSetUp

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Your session ended. Sign in again."
        case .badCode:
            return "That code is not valid, or it was already used. Wait for the next code and try again."
        case .tooManyAttempts:
            return "Too many attempts. Wait a few minutes, then try again."
        case .signInNotSetUp:
            return "Sign-in is not set up on the server yet."
        case .badStatus(let code, let call):
            switch code {
            case 409: return "That job link is already saved."
            case 400: return "The server rejected the form. Check the required fields and the salary range."
            default: return "\(call) failed: \(code)"
            }
        }
    }
}

struct APIClient {
    private let baseURL = Config.apiBaseURL
    /// The session token. Held in memory only, so every launch asks for a new code.
    var token: String?
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        session = URLSession(configuration: configuration)
    }

    func login(code: String) async throws -> String {
        let body = try JSONEncoder().encode(["code": code])
        do {
            let data = try await request("POST", "api/auth/login", body: body)
            struct Reply: Decodable { let token: String }
            return try JSONDecoder().decode(Reply.self, from: data).token
        } catch APIError.unauthorized {
            throw APIError.badCode
        }
    }

    func logout() async throws {
        _ = try await request("POST", "api/auth/logout")
    }

    func statuses() async throws -> [Status] {
        let data = try await request("GET", "api/statuses")
        return try JSONDecoder().decode([Status].self, from: data)
    }

    func applications(from: Date, to: Date) async throws -> [ApplicationEntry] {
        let query = [
            URLQueryItem(name: "from", value: Self.day(from)),
            URLQueryItem(name: "to", value: Self.day(to)),
        ]
        let data = try await request("GET", "api/applications", query: query)
        return try JSONDecoder().decode([ApplicationEntry].self, from: data)
    }

    func saveStatus(id: Int?, name: String, color: String) async throws {
        let body = try JSONEncoder().encode(["name": name, "color": color])
        if let id {
            _ = try await request("PUT", "api/statuses/\(id)", body: body)
        } else {
            _ = try await request("POST", "api/statuses", body: body)
        }
    }

    /// Sends every status id in the order they should show.
    func reorderStatuses(ids: [Int]) async throws {
        let body = try JSONEncoder().encode(["ids": ids])
        _ = try await request("PUT", "api/statuses/order", body: body)
    }

    func deleteStatus(id: Int) async throws {
        _ = try await request("DELETE", "api/statuses/\(id)")
    }

    func createApplication(_ new: NewApplication) async throws -> ApplicationEntry {
        let body = try JSONEncoder().encode(new)
        let data = try await request("POST", "api/applications", body: body)
        return try JSONDecoder().decode(ApplicationEntry.self, from: data)
    }

    func mappings() async throws -> [SiteMappingGroup] {
        let data = try await request("GET", "api/site-mappings")
        return try JSONDecoder().decode([SiteMappingGroup].self, from: data)
    }

    func inspect(url: String) async throws -> InspectResult {
        let body = try JSONEncoder().encode(["url": url])
        let data = try await request("POST", "api/site-mappings/inspect", body: body)
        return try JSONDecoder().decode(InspectResult.self, from: data)
    }

    func suggest(url: String) async throws -> [MappingEntry] {
        let body = try JSONEncoder().encode(["url": url])
        let data = try await request("POST", "api/site-mappings/suggest", body: body)
        return try JSONDecoder().decode([MappingEntry].self, from: data)
    }

    /// Same as suggest(url:), for tags the app already read in its own browser.
    func suggest(candidates: [Candidate]) async throws -> [MappingEntry] {
        struct Payload: Encodable {
            let candidates: [Candidate]
        }
        let body = try JSONEncoder().encode(Payload(candidates: candidates))
        let data = try await request("POST", "api/site-mappings/suggest-tags", body: body)
        return try JSONDecoder().decode([MappingEntry].self, from: data)
    }

    /// POST adds a website that has no rules yet, PUT replaces the rules of one that does.
    func saveMapping(host: String, entries: [MappingEntry], exists: Bool) async throws {
        struct Payload: Encodable {
            let host: String?
            let mappings: [MappingEntry]
        }
        let body = try JSONEncoder().encode(Payload(host: exists ? nil : host, mappings: entries))
        if exists {
            _ = try await request("PUT", "api/site-mappings/\(host)", body: body)
        } else {
            _ = try await request("POST", "api/site-mappings", body: body)
        }
    }

    func deleteMapping(host: String) async throws {
        _ = try await request("DELETE", "api/site-mappings/\(host)")
    }

    func updateApplication(id: Int, _ new: NewApplication) async throws -> ApplicationEntry {
        let body = try JSONEncoder().encode(new)
        let data = try await request("PUT", "api/applications/\(id)", body: body)
        return try JSONDecoder().decode(ApplicationEntry.self, from: data)
    }

    func updateStatus(id: Int, statusId: Int) async throws -> ApplicationEntry {
        let body = try JSONEncoder().encode(["statusId": statusId])
        let data = try await request("PATCH", "api/applications/\(id)/status", body: body)
        return try JSONDecoder().decode(ApplicationEntry.self, from: data)
    }

    func deleteApplication(id: Int) async throws {
        _ = try await request("DELETE", "api/applications/\(id)")
    }

    static func day(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
    }

    private func request(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> Data {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        if !query.isEmpty { components.queryItems = query }

        var urlRequest = URLRequest(url: components.url!)
        urlRequest.httpMethod = method
        if let body {
            urlRequest.httpBody = body
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let token {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: urlRequest)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        switch code {
        case 401: throw APIError.unauthorized
        case 429: throw APIError.tooManyAttempts
        case 503 where path == "api/auth/login": throw APIError.signInNotSetUp
        default: break
        }
        guard (200..<300).contains(code) else {
            throw APIError.badStatus(code: code, call: "\(method) /\(path)")
        }
        return data
    }
}
