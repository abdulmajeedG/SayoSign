import Foundation
import SwiftUI

func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

func LF(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), arguments: args)
}

struct LibraryApp: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var bundleID: String
    var version: String
    var build: String
    var minOS: String
    var size: Int64
    var added: Date
    var source: String
    var appFolder: String
    var hasPlugins: Bool
    var encrypted: Bool
}

struct SignedApp: Codable, Identifiable, Hashable {
    var id: UUID
    var libraryID: UUID?
    var name: String
    var bundleID: String
    var version: String
    var certificateName: String
    var signedAt: Date
    var ipaFile: String
    var size: Int64
    var tweaks: [String]
}

struct StoredCertificate: Codable, Identifiable, Hashable {
    var id: UUID
    var nickname: String
    var details: CertDetails
    var profile: ProfileDetails
    var p12File: String
    var profileFile: String
    var added: Date
    var ocsp: OCSPStatus
    var ocspChecked: Date?
    var revokedAt: Date?
    var fromAppleID: Bool

    var expires: Date { min(details.notAfter, profile.expiration) }
    var daysLeft: Int { max(0, Calendar.current.dateComponents([.day], from: Date(), to: expires).day ?? 0) }
    var isExpired: Bool { expires < Date() }
}

struct RepoSource: Codable, Identifiable, Hashable {
    var id: UUID
    var url: String
    var name: String
    var iconURL: String?
    var lastRefresh: Date?
    var apps: [RepoApp]
}

struct RepoApp: Codable, Identifiable, Hashable {
    var id: String { sourceID.uuidString + "|" + bundleID + "|" + version + "|" + downloadURL }
    var sourceID: UUID
    var name: String
    var bundleID: String
    var developer: String
    var subtitle: String
    var description: String
    var iconURL: String
    var version: String
    var date: String
    var downloadURL: String
    var size: Int64
    var tint: String?
    var screenshots: [String]
}

struct AppSettings: Codable, Equatable {
    var selectedCertificate: UUID?
    var compressionLevel: Int = 1
    var autoRemovePlugins = false
    var removeWatchApps = true
    var deleteAfterInstall = false
    var serverPort: Int = 47616
    var anisetteURL = "https://ani.sidestore.io"
    var bundleSuffix = ""
    var keepAliveAudio = true
    var udid = ""
    var appleIDTeam = ""
}

struct DownloadTask: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var progress: Double
    var status: String
}
