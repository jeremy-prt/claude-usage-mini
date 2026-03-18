import SwiftUI

@main
struct ClaudeUsageMiniApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        // Empty scene — everything is managed by AppDelegate
        MenuBarExtra("", isInserted: .constant(false)) {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let service = UsageService()
    let contextMonitor = ContextMonitor()
    let notificationService = NotificationService()

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var eventMonitor: Any?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = renderMenuBarIconUnauthenticated()
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let hostingView = NSHostingView(rootView:
            PopoverView(service: service, contextMonitor: contextMonitor)
        )
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = hostingView
        popover.behavior = .transient

        service.startPolling()
        contextMonitor.startMonitoring()
        notificationService.requestPermission()

        HotkeyManager.shared.onToggle = { [weak self] in
            self?.togglePopover()
        }
        HotkeyManager.shared.registerHotkey()

        NotificationCenter.default.addObserver(
            self, selector: #selector(openSettings),
            name: .openSettings, object: nil
        )

        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.updateIcon()
                self.notificationService.checkAndNotify(
                    pct5h: self.service.pct5h,
                    pct7d: self.service.pct7d
                )
            }
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            let hostingView = NSHostingView(rootView:
                PopoverView(service: service, contextMonitor: contextMonitor)
            )
            popover.contentViewController?.view = hostingView
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.popover.performClose(nil)
            }
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: L("settings"), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        if service.isAuthenticated {
            let signOutItem = NSMenuItem(title: L("disconnect"), action: #selector(signOut), keyEquivalent: "")
            signOutItem.target = self
            menu.addItem(signOutItem)
            menu.addItem(NSMenuItem.separator())
        }

        let quitItem = NSMenuItem(title: L("quit"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc func openSettings() {
        popover.performClose(nil)

        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsWindowContent(
            service: service,
            contextMonitor: contextMonitor,
            notificationService: notificationService
        )
        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L("settings").replacingOccurrences(of: "...", with: "")
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    @objc private func signOut() {
        service.signOut()
        updateIcon()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private var iconStyle: MenuBarIconStyle {
        MenuBarIconStyle(rawValue: UserDefaults.standard.string(forKey: "menuBarIconStyle") ?? "barres") ?? .barres
    }

    private func updateIcon() {
        let style = iconStyle
        statusItem.button?.image = service.isAuthenticated
            ? renderMenuBarIcon(pct5h: service.pct5h, pct7d: service.pct7d, style: style)
            : renderMenuBarIconUnauthenticated(style: style)
    }
}
