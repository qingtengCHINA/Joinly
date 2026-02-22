import Foundation

enum AppMetadata {
    static let madeBy = "Made By QingTengStudio"
    static let developmentDate = "2026-02-22"

    static var version: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0.0"
    }

    static var build: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "1"
    }

    static var versionDisplay: String {
        "v\(version) (\(build))"
    }
}
