import Foundation

/// Form values read from a job page through the rules saved for its website.
struct ImportedJob {
    var title: String?
    var company: String?
    var salaryMin: Double?
    var salaryMax: Double?
    var currency: String?
    var employmentType: String?
    var setup: String?
    var remarks: String?
    var filled = 0
}

enum JobImporter {
    static func read(_ result: InspectResult) -> ImportedJob {
        let values = Dictionary(
            result.candidates.map { ($0.id, $0.value) },
            uniquingKeysWith: { first, _ in first }
        )
        var job = ImportedJob()
        var location: String?

        for rule in result.mappings {
            guard let raw = values["\(rule.sourceType)|\(rule.sourceKey)"] else { continue }
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

            switch rule.field {
            case .title: job.title = text
            case .company: job.company = text
            case .salaryMin: job.salaryMin = numbers(in: text).first
            case .salaryMax: job.salaryMax = numbers(in: text).last
            case .salaryCurrency: job.currency = currency(in: text)
            case .employmentType: job.employmentType = employmentType(in: text)
            case .setup: job.setup = setup(in: text)
            case .location:
                location = text
                continue
            case .description, .remarks: continue
            }
            job.filled += 1
        }

        // lines recognised by their look fill whatever the saved mapping left empty
        let lines = Dictionary(
            result.candidates.filter { $0.type == "PATTERN" }.map { ($0.key, $0.value) },
            uniquingKeysWith: { first, _ in first }
        )
        if job.salaryMin == nil, let line = lines["salary"], let low = numbers(in: line).first {
            job.salaryMin = low
            job.salaryMax = numbers(in: line).last
            job.currency = job.currency ?? currency(in: line)
            job.filled += 1
        }
        if job.setup == nil, let line = lines["setup"], let found = setup(in: line) {
            job.setup = found
            job.filled += 1
        }
        if job.employmentType == nil, let line = lines["employment_type"], let found = employmentType(in: line) {
            job.employmentType = found
            job.filled += 1
        }

        // sites often put the work arrangement inside the location, like "Makati City (Hybrid)"
        if job.setup == nil, let location, let found = setup(in: location) {
            job.setup = found
            job.filled += 1
        }
        return job
    }

    /// Every amount in the text, so "₱50,000 – ₱70,000" gives both ends. "70k" counts as 70000.
    static func numbers(in text: String) -> [Double] {
        text.matches(of: /(\d[\d,]*(?:\.\d+)?)\s*([kK])?/).compactMap { match in
            guard let value = Double(match.1.replacing(",", with: "")) else { return nil }
            return match.2 == nil ? value : value * 1000
        }
    }

    static func currency(in text: String) -> String? {
        let upper = text.uppercased()
        if upper.contains("PHP") || upper.contains("₱") { return "PHP" }
        if upper.contains("USD") || upper.contains("$") { return "USD" }
        return nil
    }

    static func employmentType(in text: String) -> String? {
        let lower = text.lowercased()
        if lower.contains("part") { return "Part-time" }
        if lower.contains("contract") || lower.contains("temp") || lower.contains("freelance") {
            return "Contractual"
        }
        if lower.contains("full") { return "Full-time" }
        return nil
    }

    static func setup(in text: String) -> String? {
        let lower = text.lowercased()
        if lower.contains("hybrid") { return "Hybrid" }
        if lower.contains("remote") || lower.contains("telecommute") || lower.contains("wfh")
            || lower.contains("home") { return "WFH" }
        if lower.contains("onsite") || lower.contains("on-site") || lower.contains("office")
            || lower.contains("in-person") { return "Onsite" }
        return nil
    }
}
