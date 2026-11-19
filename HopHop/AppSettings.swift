import Foundation

/// Choices kept on this device. The keys are shared by the Settings page and the screens that read them.
enum AppSettings {
    static let defaultStatus = "hophop-default-status"          // status id, 0 = the first one
    static let defaultCurrency = "hophop-default-currency"      // PHP or USD
    static let defaultSetup = "hophop-default-setup"            // Onsite, Hybrid or WFH
    static let defaultEmployment = "hophop-default-employment"  // empty = not specified
    static let weekStart = "hophop-week-start"                  // 0 = Sunday, 1 = Monday

    static var currency: String { UserDefaults.standard.string(forKey: defaultCurrency) ?? "PHP" }
    static var setup: String { UserDefaults.standard.string(forKey: defaultSetup) ?? "Onsite" }
    static var employment: String? {
        let value = UserDefaults.standard.string(forKey: defaultEmployment) ?? ""
        return value.isEmpty ? nil : value
    }
    static var status: Int { UserDefaults.standard.integer(forKey: defaultStatus) }
}
