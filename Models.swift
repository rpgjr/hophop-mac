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
    let link: String
    let appliedDate: String
    var status: Status
}

extension ApplicationEntry {
    var salaryText: String {
        guard let low = salaryMin else { return "Not listed" }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = salaryCurrency
        formatter.locale = Locale(identifier: "en_PH")
        formatter.maximumFractionDigits = 0

        let lowText = formatter.string(from: NSNumber(value: low)) ?? "\(low)"
        guard let high = salaryMax, high != low else { return lowText }
        let highText = formatter.string(from: NSNumber(value: high)) ?? "\(high)"
        return "\(lowText) – \(highText)"
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
    let link: String
    let appliedDate: String
}

enum JobOptions {
    static let currencies = ["PHP", "USD"]
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

struct SiteMappingGroup: Codable, Identifiable, Hashable {
    let host: String
    var mappings: [MappingEntry]
    var id: String { host }
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
    let mappings: [MappingEntry]
}
