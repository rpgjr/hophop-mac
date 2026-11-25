import Foundation

struct Status: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let color: String
}

struct ApplicationEntry: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let company: String
    let salaryMin: Double?
    let salaryMax: Double?
    let salaryCurrency: String
    let employmentType: String?
    let setup: String
    let remarks: String?
    let location: String?
    let website: String?
    let description: String?
    let link: String
    let appliedDate: String
    var status: Status
}

/// One status change of an application. fromStatus is nil for the first entry.
struct StatusHistoryEntry: Codable, Identifiable, Hashable {
    let id: Int
    let fromStatus: String?
    let fromColor: String?
    let toStatus: String
    let toColor: String
    let changedAt: String
}

extension ApplicationEntry {
    var salaryText: String {
        guard let low = salaryMin else { return "Not listed" }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_PH")
        formatter.maximumFractionDigits = 0

        // letters in the symbol, like RM, read better with a space: "RM 7,000"
        let symbol = JobOptions.symbol(for: salaryCurrency)
        let prefix = symbol.last?.isLetter == true ? "\(symbol) " : symbol
        func text(_ value: Double) -> String {
            prefix + (formatter.string(from: NSNumber(value: value)) ?? "\(value)")
        }

        let lowText = text(low)
        guard let high = salaryMax, high != low else { return lowText }
        return "\(lowText) – \(text(high))"
    }
}

extension ApplicationEntry {
    // Plain, non-optional values so a Table column can sort on them.
    var salarySort: Double { salaryMin ?? .infinity }
    var statusName: String { status.name }

    var appliedDateText: String {
        guard let date = try? Date(appliedDate, strategy: .iso8601.year().month().day()) else {
            return appliedDate
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

struct NewApplication: Encodable {
    let statusId: Int
    let title: String
    let company: String
    let salaryMin: Double?
    let salaryMax: Double?
    let salaryCurrency: String
    let employmentType: String?
    let setup: String
    let remarks: String?
    let location: String?
    let website: String?
    let description: String?
    let link: String
    let appliedDate: String
}

enum JobOptions {
    static let currencies = ["PHP", "USD", "MYR", "SGD", "EUR", "GBP", "AUD", "JPY"]

    /// What each currency is written with in front of an amount, like "RM 7,000".
    static func symbol(for code: String) -> String {
        switch code {
        case "PHP": "₱"
        case "USD": "$"
        case "MYR": "RM"
        case "SGD": "S$"
        case "EUR": "€"
        case "GBP": "£"
        case "AUD": "A$"
        case "JPY": "¥"
        default: code
        }
    }
    static let setups = ["Onsite", "Hybrid", "WFH"]
    static let employmentTypes = ["Full-time", "Part-time", "Contractual"]
}

// MARK: - Site mappings

enum MappingField: String, CaseIterable, Identifiable, Codable {
    case title = "TITLE"
    case company = "COMPANY"
    case salaryMin = "SALARY_MIN"
    case salaryMax = "SALARY_MAX"
    case salaryCurrency = "SALARY_CURRENCY"
    case employmentType = "EMPLOYMENT_TYPE"
    case setup = "SETUP"
    case location = "LOCATION"
    case description = "DESCRIPTION"
    case remarks = "REMARKS"

    var id: String { rawValue }

    /// Remarks is the user's own note on an application, so no website fills it.
    static var mappable: [MappingField] { allCases.filter { $0 != .remarks } }

    var label: String {
        switch self {
        case .title: "Title"
        case .company: "Company"
        case .salaryMin: "Salary min"
        case .salaryMax: "Salary max"
        case .salaryCurrency: "Currency"
        case .employmentType: "Employment type"
        case .setup: "Setup"
        case .location: "Location"
        case .description: "Description"
        case .remarks: "Remarks"
        }
    }
}

struct MappingEntry: Codable, Hashable {
    var field: MappingField
    var sourceType: String
    var sourceKey: String
}

/// One named mapping of a website, for one country. A website can have several.
struct SiteMappingGroup: Codable, Identifiable, Hashable {
    let id: Int
    var name: String
    let host: String
    var country: String?
    var mappings: [MappingEntry]

    /// "Jobstreet PH" or, with a country, "Jobstreet PH · Philippines"
    var title: String { country.map { "\(name) · \($0)" } ?? name }
}

struct Candidate: Codable, Identifiable, Hashable {
    let type: String
    let key: String
    let value: String
    var id: String { "\(type)|\(key)" }
}

struct InspectResult: Codable {
    let host: String
    let candidates: [Candidate]
    let groups: [SiteMappingGroup]
}
