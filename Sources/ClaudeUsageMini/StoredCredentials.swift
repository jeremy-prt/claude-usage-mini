import Foundation

struct StoredCredentials: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let scopes: [String]

    var hasRefreshToken: Bool {
        guard let refreshToken else { return false }
        return !refreshToken.isEmpty
    }

    func needsRefresh(at now: Date = Date(), leeway: TimeInterval = 300) -> Bool {
        guard hasRefreshToken, let expiresAt else { return false }
        return expiresAt <= now.addingTimeInterval(leeway)
    }

    func isExpired(at now: Date = Date()) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt <= now
    }
}

struct StoredCredentialsStore: Sendable {
    let directoryURL: URL
    let credentialsFileURL: URL

    init(
        directoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/claude-usage-mini", isDirectory: true)
    ) {
        self.directoryURL = directoryURL
        self.credentialsFileURL = directoryURL.appendingPathComponent("credentials.json")
    }

    func save(_ credentials: StoredCredentials) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directoryURL.path)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(credentials)
        try data.write(to: credentialsFileURL, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: credentialsFileURL.path)
    }

    func load(defaultScopes: [String]) -> StoredCredentials? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: credentialsFileURL),
              let credentials = try? decoder.decode(StoredCredentials.self, from: data) else {
            return nil
        }
        return credentials
    }

    func delete() {
        try? FileManager.default.removeItem(at: credentialsFileURL)
    }
}
