import AppKit
import SwiftUI

@MainActor
enum ContainerDesktopMainWindow {
    static let identifier = NSUserInterfaceItemIdentifier("io.shiguanghuxian.containerdesktop.main-window")
    private static var openAction: (() -> Void)?

    static func configureOpenAction(_ action: @escaping () -> Void) {
        openAction = action
    }

    static func mark(_ window: NSWindow) {
        window.identifier = identifier
    }

    static func find(in app: NSApplication = .shared) -> NSWindow? {
        mainWindows(in: app).first
    }

    static func activateOrOpen(
        in app: NSApplication = .shared,
        open: () -> Void = { openAction?() }
    ) {
        app.activate(ignoringOtherApps: true)

        if let window = find(in: app) {
            closeDuplicateMainWindows(keeping: window, in: app)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }

        open()
        DispatchQueue.main.async {
            if let window = find(in: app) {
                closeDuplicateMainWindows(keeping: window, in: app)
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }

    static func closeDuplicateMainWindows(keeping windowToKeep: NSWindow, in app: NSApplication = .shared) {
        for window in mainWindows(in: app) where window !== windowToKeep {
            window.close()
        }
    }

    private static func mainWindows(in app: NSApplication) -> [NSWindow] {
        app.windows.filter { $0.identifier == identifier }
    }
}

@MainActor
enum ContainerDesktopWindowRouter {
    private static var openSettingsAction: (() -> Void)?

    static func configure(openSettings: @escaping () -> Void) {
        openSettingsAction = openSettings
    }

    static func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        openSettingsAction?()
    }
}

struct MainWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        markWindow(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        markWindow(for: nsView)
    }

    private func markWindow(for view: NSView) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            ContainerDesktopMainWindow.mark(window)
            ContainerDesktopMainWindow.closeDuplicateMainWindows(keeping: window)
        }
    }
}
