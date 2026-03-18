import SwiftUI

struct PopoverView: View {
    @ObservedObject var service: UsageService
    @ObservedObject var contextMonitor: ContextMonitor
    @AppStorage("monochromeMode") private var monochrome = false
    @AppStorage("appLanguage") private var language = "en"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !service.isAuthenticated {
                signInView
            } else {
                usageView
            }
        }
        .padding(16)
        .frame(width: 320)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }

    // MARK: - Connexion

    @ViewBuilder
    private var signInView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("claude_usage"))
                .font(.headline)

            if service.isAwaitingCode {
                CodeEntryView(service: service)
            } else {
                Text(L("sign_in_prompt"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button(L("sign_in_button")) {
                    service.startOAuthFlow()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }

            if let error = service.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Divider()

            HStack {
                Spacer()
                Button(L("quit")) { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Utilisation

    @ViewBuilder
    private var usageView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("claude_usage"))
                    .font(.headline)
                Spacer()
                if let email = service.accountEmail {
                    Text(email)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            UsageBar(
                label: L("session_5h"),
                percent: service.pct5h,
                resetDate: service.reset5h,
                monochrome: monochrome
            )

            UsageBar(
                label: L("session_7d"),
                percent: service.pct7d,
                resetDate: service.reset7d,
                monochrome: monochrome
            )

            if let opus = service.usage?.sevenDayOpus, opus.utilization != nil {
                Divider()
                Text(L("per_model_7d"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                UsageBar(
                    label: "Opus",
                    percent: (opus.utilization ?? 0) / 100.0,
                    resetDate: opus.resetsAtDate,
                    monochrome: monochrome
                )
                if let sonnet = service.usage?.sevenDaySonnet {
                    UsageBar(
                        label: "Sonnet",
                        percent: (sonnet.utilization ?? 0) / 100.0,
                        resetDate: sonnet.resetsAtDate,
                        monochrome: monochrome
                    )
                }
            }

            if let extra = service.usage?.extraUsage, extra.isEnabled {
                Divider()
                ExtraUsageBar(extra: extra, monochrome: monochrome)
            }

            if contextMonitor.isEnabled {
                Divider()
                if let ctx = contextMonitor.snapshot {
                    ContextBar(snapshot: ctx, monochrome: monochrome)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("context_window"))
                            .font(.subheadline.weight(.medium))
                        Text(L("no_active_session"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                if let updated = service.lastUpdated {
                    HStack(spacing: 0) {
                        Text(language == "fr" ? "Mis à jour il y a " : "Updated ")
                        Text(updated, style: .relative)
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
                Spacer()
                Button {
                    Task { await service.fetchUsage() }
                    contextMonitor.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.45))
                }
                .buttonStyle(.borderless)

                Button {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.45))
                }
                .buttonStyle(.borderless)
            }

            if let error = service.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.caption2)
            }
        }
    }
}

// MARK: - Barre d'utilisation

private struct UsageBar: View {
    let label: String
    let percent: Double
    let resetDate: Date?
    let monochrome: Bool

    private var color: Color {
        monochrome ? .primary : colorForPercent(percent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline.weight(monochrome ? .bold : .medium))
                Spacer()
                Text("\(Int(round(percent * 100)))%")
                    .font(.subheadline.monospacedDigit().weight(monochrome ? .bold : .semibold))
                    .foregroundStyle(monochrome ? .primary : color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(monochrome ? AnyShapeStyle(Color.black.opacity(0.5)) : AnyShapeStyle(color.gradient))
                        .frame(width: max(0, geo.size.width * min(percent, 1.0)), height: 6)
                }
            }
            .frame(height: 6)

            if let resetDate {
                Text(resetDate, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Usage supplémentaire

private struct ExtraUsageBar: View {
    let extra: ExtraUsage
    let monochrome: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(L("extra_usage"))
                    .font(.subheadline.weight(.medium))
                Spacer()
                if let used = extra.usedCreditsAmount, let limit = extra.monthlyLimitAmount {
                    Text("\(ExtraUsage.formatUSD(used)) / \(ExtraUsage.formatUSD(limit))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            if let pct = extra.utilization {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.quaternary)
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(monochrome ? AnyShapeStyle(.primary.opacity(0.6)) : AnyShapeStyle(Color.blue.gradient))
                            .frame(width: max(0, geo.size.width * min(pct / 100.0, 1.0)), height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
    }
}

// MARK: - Fenêtre de contexte

private struct ContextBar: View {
    let snapshot: ContextSnapshot
    let monochrome: Bool

    private var contextColor: Color {
        if monochrome { return .primary }
        if snapshot.usagePercent >= snapshot.autoCompactThreshold { return .red }
        return .blue
    }

    private var compactColor: Color {
        if monochrome { return .secondary }
        return snapshot.percentUntilCompact > 0 ? .blue : .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(L("context_window"))
                    .font(.subheadline.weight(monochrome ? .bold : .medium))
                Spacer()
                Text("\(Int(round(snapshot.usagePercent * 100)))%")
                    .font(.subheadline.monospacedDigit().weight(monochrome ? .bold : .semibold))
                    .foregroundStyle(monochrome ? .primary : contextColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(monochrome ? Color.gray.opacity(0.5) : Color.blue.opacity(0.5))
                        .frame(width: 1.5, height: 10)
                        .offset(x: geo.size.width * snapshot.autoCompactThreshold - 0.75)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(monochrome ? AnyShapeStyle(Color.black.opacity(0.5)) : AnyShapeStyle(contextColor.gradient))
                        .frame(width: max(0, geo.size.width * min(snapshot.usagePercent, 1.0)), height: 6)
                }
            }
            .frame(height: 10)

            HStack {
                Text(formatTokens(snapshot.totalContextTokens) + " / " + formatTokens(snapshot.maxContextTokens))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                Spacer()
                if snapshot.percentUntilCompact > 0 {
                    Text(String(format: L("before_compact"), Int(round(snapshot.percentUntilCompact * 100))))
                        .font(.caption2)
                        .foregroundStyle(compactColor)
                } else {
                    Text(L("compact_imminent"))
                        .font(.caption2)
                        .foregroundStyle(compactColor)
                }
            }

            Text(snapshot.model)
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        }
        if count >= 1_000 {
            return String(format: "%.0fK", Double(count) / 1_000.0)
        }
        return "\(count)"
    }
}

// MARK: - Saisie du code

private struct CodeEntryView: View {
    @ObservedObject var service: UsageService
    @State private var code = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("paste_code"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField(L("paste_placeholder"), text: $code)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onSubmit { submit() }

            HStack {
                Button(L("cancel")) { service.isAwaitingCode = false }
                    .buttonStyle(.borderless)
                Spacer()
                Button(L("submit")) { submit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(code.isEmpty)
            }
        }
    }

    private func submit() {
        let value = code
        Task { await service.submitOAuthCode(value) }
    }
}

// MARK: - Helpers

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}

func colorForPercent(_ pct: Double) -> Color {
    switch pct {
    case ..<0.60: return .orange
    case 0.60..<0.85: return Color(red: 0.9, green: 0.45, blue: 0.0)
    default: return .red
    }
}
