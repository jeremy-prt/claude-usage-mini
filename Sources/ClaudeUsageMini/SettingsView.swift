import SwiftUI
import ServiceManagement

enum SettingsTab: String, CaseIterable {
    case general, hotkey, appearance, account

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .hotkey: "keyboard"
        case .appearance: "paintbrush"
        case .account: "person.crop.circle"
        }
    }

    var label: String {
        switch self {
        case .general: Lsync("general")
        case .hotkey: Lsync("hotkey_section")
        case .appearance: Lsync("appearance")
        case .account: Lsync("account")
        }
    }
}

struct SettingsWindowContent: View {
    @ObservedObject var service: UsageService
    @ObservedObject var contextMonitor: ContextMonitor
    @ObservedObject var notificationService: NotificationService
    @AppStorage("monochromeMode") private var monochrome = false
    @AppStorage("menuBarIconStyle") private var iconStyle = "barres"
    @AppStorage("appLanguage") private var language = "en"
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 20))
                            Text(tab.label)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(selectedTab == tab ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)

            Divider()
                .padding(.top, 4)

            // Content
            Group {
                switch selectedTab {
                case .general:
                    generalTab
                case .hotkey:
                    hotkeyTab
                case .appearance:
                    appearanceTab
                case .account:
                    accountTab
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { focusSettingsWindow() }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section(L("general")) {
                LaunchAtLoginToggle()

                VStack(alignment: .leading, spacing: 4) {
                    Picker(L("polling_interval"), selection: Binding(
                        get: { service.pollingMinutes },
                        set: { service.updatePollingInterval($0) }
                    )) {
                        ForEach(UsageService.pollingOptions, id: \.self) { mins in
                            Text(pollingLabel(mins)).tag(mins)
                        }
                    }
                    Text(L("polling_footer"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Picker(L("language"), selection: $language) {
                    ForEach(Lang.allCases, id: \.rawValue) { lang in
                        Text(lang.label).tag(lang.rawValue)
                    }
                }
            }

            Section(L("context_section")) {
                Toggle(L("show_context"), isOn: $contextMonitor.isEnabled)

                if contextMonitor.isEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        Picker(L("context_refresh"), selection: $contextMonitor.refreshSeconds) {
                            ForEach(ContextMonitor.refreshOptions, id: \.self) { secs in
                                Text(contextRefreshLabel(secs)).tag(secs)
                            }
                        }
                        Text(L("context_footer"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section(L("notifications")) {
                Toggle(L("notif_enabled"), isOn: $notificationService.isEnabled)

                if notificationService.isEnabled {
                    HStack {
                        Text(L("notif_threshold_5h"))
                        Spacer()
                        Text("\(notificationService.threshold5h)%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { Double(notificationService.threshold5h) },
                            set: { notificationService.threshold5h = Int($0) }
                        ),
                        in: 40...100,
                        step: 5
                    )
                    .controlSize(.small)

                    HStack {
                        Text(L("notif_threshold_7d"))
                        Spacer()
                        Text("\(notificationService.threshold7d)%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { Double(notificationService.threshold7d) },
                            set: { notificationService.threshold7d = Int($0) }
                        ),
                        in: 40...100,
                        step: 5
                    )
                    .controlSize(.small)

                    VStack(alignment: .leading, spacing: 4) {
                        Button(L("notif_test")) {
                            notificationService.sendTest()
                        }
                        .controlSize(.small)
                        Text(L("notif_footer"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Hotkey

    private var hotkeyTab: some View {
        Form {
            Section(L("hotkey_section")) {
                HotkeySettingView()
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Appearance

    private var appearanceTab: some View {
        Form {
            Section(L("appearance")) {
                Picker(L("menubar_icon"), selection: $iconStyle) {
                    Text(L("icon_bars")).tag("barres")
                    Text(L("icon_logo")).tag("icone")
                    Text(L("icon_both")).tag("les2")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle(L("monochrome"), isOn: $monochrome)
                    Text(L("monochrome_desc"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Account

    private var accountTab: some View {
        Form {
            Section(L("account")) {
                if service.isAuthenticated {
                    if let email = service.accountEmail {
                        LabeledContent("Email", value: email)
                    }
                    Button(L("sign_out"), role: .destructive) {
                        service.signOut()
                    }
                } else {
                    Text(L("not_signed_in"))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Helpers

    private func pollingLabel(_ mins: Int) -> String {
        if mins < 60 { return "\(mins) min" }
        let hourLabel = language == "fr" ? "heure" : "hour"
        return "\(mins / 60) \(hourLabel)"
    }

    private func contextRefreshLabel(_ secs: Int) -> String {
        if secs < 60 { return "\(secs) sec" }
        return "\(secs / 60) min"
    }
}

@MainActor
private func focusSettingsWindow() {
    DispatchQueue.main.async {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.last(where: { $0.isVisible && $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
}

// MARK: - Hotkey

struct HotkeySettingView: View {
    @ObservedObject private var manager = HotkeyManager.shared

    var body: some View {
        HStack {
            Text(L("hotkey_toggle"))
            Spacer()
            HStack(spacing: 8) {
                Button {
                    if manager.isRecording {
                        manager.stopRecording()
                    } else {
                        manager.startRecording()
                    }
                } label: {
                    Group {
                        if manager.isRecording {
                            Text(L("hotkey_recording_short"))
                                .foregroundStyle(.orange)
                        } else if let combo = manager.currentHotkey {
                            Text(combo.displayString)
                                .foregroundStyle(.primary)
                        } else {
                            Text(L("hotkey_define"))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.system(.callout, design: .rounded))
                    .frame(minWidth: 60)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(.quaternary, in: Capsule())
                }
                .buttonStyle(.plain)

                if manager.currentHotkey != nil {
                    Button {
                        manager.clearHotkey()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Launch at Login

struct LaunchAtLoginToggle: View {
    @StateObject private var model = LaunchAtLoginModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(L("launch_at_login"), isOn: Binding(
                get: { model.isEnabled },
                set: { model.setEnabled($0) }
            ))
            .disabled(!model.isSupported)

            if let message = model.message {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

@MainActor
final class LaunchAtLoginModel: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var isSupported: Bool
    @Published private(set) var message: String?

    init() {
        let appURL = Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL
        let appPath = appURL.path
        let appDirs = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appending(path: "Applications", directoryHint: .isDirectory)
        ]
        isSupported = appDirs.contains { dir in
            let dirPath = dir.resolvingSymlinksInPath().standardizedFileURL.path
            return appPath == dirPath || appPath.hasPrefix(dirPath + "/")
        }

        guard isSupported else {
            message = L("install_for_login")
            return
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        guard isSupported else { return }
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            isEnabled = enabled
            message = nil
        } catch {
            isEnabled = SMAppService.mainApp.status == .enabled
            message = L("login_update_failed")
        }
    }
}
