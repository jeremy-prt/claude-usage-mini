import Foundation
import CryptoKit
import AppKit

@MainActor
class UsageService: ObservableObject {
    @Published var usage: UsageResponse?
    @Published var lastError: String?
    @Published var lastUpdated: Date?
    @Published var isAuthenticated = false
    @Published var isAwaitingCode = false
    @Published private(set) var accountEmail: String?
    @Published private(set) var pollingMinutes: Int

    private var timer: Timer?
    private let session: URLSession
    private var currentInterval: TimeInterval
    private let credentialsStore: StoredCredentialsStore

    static let defaultPollingMinutes = 15
    static let pollingOptions = [15, 30, 60]
    nonisolated static let maxBackoffInterval: TimeInterval = 60 * 60
    nonisolated static let defaultOAuthScopes = ["user:profile", "user:inference"]

    private let clientId = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    private let redirectUri = "https://platform.claude.com/oauth/code/callback"
    nonisolated private static let authorizeEndpoint = URL(string: "https://claude.ai/oauth/authorize")!
    nonisolated private static let usageEndpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    nonisolated private static let userinfoEndpoint = URL(string: "https://api.anthropic.com/api/oauth/userinfo")!
    nonisolated private static let tokenEndpoint = URL(string: "https://platform.claude.com/v1/oauth/token")!

    private var codeVerifier: String?
    private var oauthState: String?
    private var refreshTask: Task<RefreshResult, Never>?

    var pct5h: Double { (usage?.fiveHour?.utilization ?? 0) / 100.0 }
    var pct7d: Double { (usage?.sevenDay?.utilization ?? 0) / 100.0 }
    var reset5h: Date? { usage?.fiveHour?.resetsAtDate }
    var reset7d: Date? { usage?.sevenDay?.resetsAtDate }

    private enum RefreshResult { case success, permanentFailure, transientFailure }

    init(credentialsStore: StoredCredentialsStore = StoredCredentialsStore()) {
        self.session = .shared
        self.credentialsStore = credentialsStore
        let stored = UserDefaults.standard.integer(forKey: "pollingMinutes")
        let minutes = Self.pollingOptions.contains(stored) ? stored : Self.defaultPollingMinutes
        self.pollingMinutes = minutes
        self.currentInterval = TimeInterval(minutes * 60)
        self.isAuthenticated = credentialsStore.load(defaultScopes: Self.defaultOAuthScopes) != nil
    }

    func updatePollingInterval(_ minutes: Int) {
        pollingMinutes = minutes
        UserDefaults.standard.set(minutes, forKey: "pollingMinutes")
        currentInterval = TimeInterval(minutes * 60)
        if isAuthenticated {
            scheduleTimer()
            Task { await fetchUsage() }
        }
    }

    // MARK: - Polling

    func startPolling() {
        guard isAuthenticated else { return }
        Task {
            await fetchUsage()
            if accountEmail == nil { await fetchProfile() }
        }
        scheduleTimer()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: currentInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isAuthenticated else { return }
                Task { await self.fetchUsage() }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: - OAuth PKCE

    func startOAuthFlow() {
        let verifier = generateCodeVerifier()
        let challenge = generateCodeChallenge(from: verifier)
        let state = generateCodeVerifier()
        codeVerifier = verifier
        oauthState = state

        var components = URLComponents(url: Self.authorizeEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "code", value: "true"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: Self.defaultOAuthScopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]

        if let url = components.url {
            NSWorkspace.shared.open(url)
            isAwaitingCode = true
        }
    }

    func submitOAuthCode(_ rawCode: String) async {
        let parts = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "#", maxSplits: 1)
        let code = String(parts[0])

        if parts.count > 1 {
            let returnedState = String(parts[1])
            guard returnedState == oauthState else {
                lastError = L("oauth_error")
                isAwaitingCode = false
                codeVerifier = nil
                oauthState = nil
                return
            }
        }

        guard let verifier = codeVerifier else {
            lastError = L("no_oauth_flow")
            isAwaitingCode = false
            return
        }

        var request = URLRequest(url: Self.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "state": oauthState ?? "",
            "client_id": clientId,
            "redirect_uri": redirectUri,
            "code_verifier": verifier,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                lastError = L("token_exchange_failed")
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let credentials = credentials(from: json) else {
                lastError = L("invalid_response")
                return
            }
            try credentialsStore.save(credentials)
            isAuthenticated = true
            isAwaitingCode = false
            lastError = nil
            codeVerifier = nil
            oauthState = nil
            await fetchProfile()
            startPolling()
        } catch {
            lastError = "\(L("auth_error")): \(error.localizedDescription)"
        }
    }

    func signOut() {
        credentialsStore.delete()
        isAuthenticated = false
        usage = nil
        lastUpdated = nil
        accountEmail = nil
        timer?.invalidate()
        timer = nil
        refreshTask?.cancel()
        refreshTask = nil
        lastError = nil
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded()
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64URLEncoded()
    }

    // MARK: - API

    func fetchUsage() async {
        guard credentialsStore.load(defaultScopes: Self.defaultOAuthScopes) != nil else {
            lastError = L("not_signed_in")
            isAuthenticated = false
            return
        }

        do {
            guard let result = try await sendAuthorizedRequest(to: Self.usageEndpoint) else { return }
            let (data, http) = result
            if http.statusCode == 429 {
                let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init)
                currentInterval = min(max(retryAfter ?? currentInterval, currentInterval * 2), Self.maxBackoffInterval)
                lastError = L("rate_limited")
                scheduleTimer()
                return
            }
            guard http.statusCode == 200 else {
                lastError = "HTTP \(http.statusCode)"
                return
            }
            let decoded = try JSONDecoder().decode(UsageResponse.self, from: data)
            usage = decoded.reconciled(with: usage)
            lastError = nil
            lastUpdated = Date()
            if currentInterval != TimeInterval(pollingMinutes * 60) {
                currentInterval = TimeInterval(pollingMinutes * 60)
                scheduleTimer()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func fetchProfile() async {
        // Try local first
        if let local = Self.loadLocalProfile() {
            accountEmail = local
            return
        }
        guard let result = try? await sendAuthorizedRequest(to: Self.userinfoEndpoint, expireOnFail: false) else { return }
        let (data, http) = result
        guard http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        if let email = json["email"] as? String, !email.isEmpty { accountEmail = email }
        else if let name = json["name"] as? String, !name.isEmpty { accountEmail = name }
    }

    nonisolated private static func loadLocalProfile() -> String? {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let account = json["oauthAccount"] as? [String: Any] else { return nil }
        return (account["emailAddress"] as? String) ?? (account["displayName"] as? String)
    }

    // MARK: - Authorized Requests

    private func sendAuthorizedRequest(to url: URL, expireOnFail: Bool = true) async throws -> (Data, HTTPURLResponse)? {
        guard let creds = credentialsStore.load(defaultScopes: Self.defaultOAuthScopes) else {
            lastError = L("not_signed_in")
            isAuthenticated = false
            return nil
        }

        if creds.needsRefresh() {
            let result = await refreshCredentials(force: true)
            if result != .success, creds.isExpired() {
                if result == .permanentFailure, expireOnFail { expireSession() }
                return nil
            }
        }

        let activeCreds = credentialsStore.load(defaultScopes: Self.defaultOAuthScopes) ?? creds
        var result = try await performRequest(token: activeCreds.accessToken, url: url)

        if result.1.statusCode == 401 {
            let refreshResult = await refreshCredentials(force: true)
            if refreshResult == .success,
               let refreshed = credentialsStore.load(defaultScopes: Self.defaultOAuthScopes) {
                result = try await performRequest(token: refreshed.accessToken, url: url)
                if result.1.statusCode == 401, expireOnFail { expireSession(); return nil }
            } else {
                if expireOnFail { expireSession() }
                return nil
            }
        }

        return result
    }

    private func performRequest(token: String, url: URL) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }

    private func refreshCredentials(force: Bool) async -> RefreshResult {
        if let refreshTask { return await refreshTask.value }
        let task = Task { [weak self] () -> RefreshResult in
            guard let self else { return .permanentFailure }
            return await self.performRefresh()
        }
        refreshTask = task
        let result = await task.value
        refreshTask = nil
        return result
    }

    private func performRefresh() async -> RefreshResult {
        guard let creds = credentialsStore.load(defaultScopes: Self.defaultOAuthScopes),
              let refreshToken = creds.refreshToken, !refreshToken.isEmpty else {
            return .permanentFailure
        }

        var request = URLRequest(url: Self.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId,
        ]
        if !creds.scopes.isEmpty { body["scope"] = creds.scopes.joined(separator: " ") }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .transientFailure }
            guard http.statusCode == 200 else {
                return http.statusCode >= 400 && http.statusCode < 500 ? .permanentFailure : .transientFailure
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let updated = credentials(from: json, fallback: creds) else {
                return .transientFailure
            }
            try credentialsStore.save(updated)
            isAuthenticated = true
            return .success
        } catch {
            return .transientFailure
        }
    }

    private func credentials(from json: [String: Any], fallback: StoredCredentials? = nil) -> StoredCredentials? {
        guard let accessToken = json["access_token"] as? String, !accessToken.isEmpty else { return nil }
        let scopes = (json["scope"] as? String)?.split(whereSeparator: \.isWhitespace).map(String.init)
            ?? fallback?.scopes ?? Self.defaultOAuthScopes
        let expiresAt: Date? = {
            if let seconds = json["expires_in"] as? Double { return Date().addingTimeInterval(seconds) }
            if let seconds = json["expires_in"] as? Int { return Date().addingTimeInterval(TimeInterval(seconds)) }
            return fallback?.expiresAt
        }()
        return StoredCredentials(
            accessToken: accessToken,
            refreshToken: (json["refresh_token"] as? String) ?? fallback?.refreshToken,
            expiresAt: expiresAt,
            scopes: scopes
        )
    }

    private func expireSession() {
        credentialsStore.delete()
        isAuthenticated = false
        usage = nil
        lastUpdated = nil
        accountEmail = nil
        timer?.invalidate()
        timer = nil
        refreshTask?.cancel()
        refreshTask = nil
        lastError = L("session_expired")
    }
}

extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
