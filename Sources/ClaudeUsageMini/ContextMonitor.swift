import Foundation

struct ContextSnapshot: Sendable {
    let model: String
    let inputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let outputTokens: Int
    let totalContextTokens: Int
    let maxContextTokens: Int
    let usagePercent: Double
    let autoCompactThreshold: Double
    let percentUntilCompact: Double
    let sessionFile: String
    let timestamp: Date
}

@MainActor
class ContextMonitor: ObservableObject {
    @Published var snapshot: ContextSnapshot?
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "showContext")
            if isEnabled { startMonitoring() } else { stopMonitoring(); snapshot = nil }
        }
    }
    @Published var refreshSeconds: Int {
        didSet {
            UserDefaults.standard.set(refreshSeconds, forKey: "contextRefreshSeconds")
            if isEnabled { startMonitoring() }
        }
    }

    private var timer: Timer?
    private let claudeDir: URL

    static let refreshOptions = [5, 10, 30, 60]
    nonisolated static let modelMaxContext: [String: Int] = [
        "claude-opus-4-6": 1_000_000,
        "claude-opus-4-5-20250414": 200_000,
        "claude-sonnet-4-6": 200_000,
        "claude-sonnet-4-5-20250514": 200_000,
        "claude-haiku-4-5-20251001": 200_000,
    ]
    nonisolated static let defaultMaxContext = 200_000
    nonisolated static let autoCompactThreshold = 0.75

    init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "showContext") as? Bool ?? true
        let stored = UserDefaults.standard.integer(forKey: "contextRefreshSeconds")
        self.refreshSeconds = Self.refreshOptions.contains(stored) ? stored : 10
        self.claudeDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    }

    func startMonitoring() {
        refresh()
        timer?.invalidate()
        let interval = TimeInterval(refreshSeconds)
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard isEnabled else {
            snapshot = nil
            return
        }
        Task.detached { [claudeDir] in
            let result = Self.readLatestSession(claudeDir: claudeDir)
            await MainActor.run { [weak self] in
                self?.snapshot = result
            }
        }
    }

    // MARK: - Session file scanning

    nonisolated private static func readLatestSession(claudeDir: URL) -> ContextSnapshot? {
        let projectsDir = claudeDir.appendingPathComponent("projects")
        let fm = FileManager.default

        guard let projectDirs = try? fm.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return nil
        }

        var latestFile: URL?
        var latestDate: Date = .distantPast

        for projectDir in projectDirs {
            guard let files = try? fm.contentsOfDirectory(at: projectDir, includingPropertiesForKeys: [.contentModificationDateKey]) else { continue }
            for file in files where file.pathExtension == "jsonl" {
                if let attrs = try? fm.attributesOfItem(atPath: file.path),
                   let modDate = attrs[.modificationDate] as? Date,
                   modDate > latestDate {
                    latestDate = modDate
                    latestFile = file
                }
            }
        }

        guard let sessionFile = latestFile else { return nil }

        // Only consider recent sessions (modified in last 30 min)
        guard Date().timeIntervalSince(latestDate) < 1800 else { return nil }

        return parseSessionFile(sessionFile)
    }

    nonisolated private static func parseSessionFile(_ url: URL) -> ContextSnapshot? {
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else { return nil }

        let lines = content.components(separatedBy: .newlines)

        var lastModel: String?
        var lastUsage: [String: Any]?
        var lastTimestamp: Date?

        // Read from the end for efficiency
        for line in lines.reversed() {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let message = json["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any],
                  usage["input_tokens"] != nil else { continue }

            lastUsage = usage
            lastModel = message["model"] as? String

            if let ts = json["timestamp"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                lastTimestamp = formatter.date(from: ts)
            }
            break
        }

        guard let usage = lastUsage else { return nil }

        let inputTokens = (usage["input_tokens"] as? Int) ?? 0
        let cacheCreation = (usage["cache_creation_input_tokens"] as? Int) ?? 0
        let cacheRead = (usage["cache_read_input_tokens"] as? Int) ?? 0
        let outputTokens = (usage["output_tokens"] as? Int) ?? 0

        let model = lastModel ?? "unknown"
        let maxContext = modelMaxContext[model] ?? defaultMaxContext
        let totalContext = inputTokens + cacheCreation + cacheRead

        let usagePercent = min(Double(totalContext) / Double(maxContext), 1.0)
        let percentUntilCompact = max(autoCompactThreshold - usagePercent, 0)

        return ContextSnapshot(
            model: model,
            inputTokens: inputTokens,
            cacheCreationTokens: cacheCreation,
            cacheReadTokens: cacheRead,
            outputTokens: outputTokens,
            totalContextTokens: totalContext,
            maxContextTokens: maxContext,
            usagePercent: usagePercent,
            autoCompactThreshold: autoCompactThreshold,
            percentUntilCompact: percentUntilCompact,
            sessionFile: url.lastPathComponent,
            timestamp: lastTimestamp ?? Date()
        )
    }
}
