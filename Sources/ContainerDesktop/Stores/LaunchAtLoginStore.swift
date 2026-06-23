import Foundation
import Observation

@MainActor
@Observable
final class LaunchAtLoginStore {
    @ObservationIgnored private let service: any LaunchAtLoginServicing

    var status: LaunchAtLoginStatus
    var isUpdating = false
    var errorMessage: String?

    init(service: any LaunchAtLoginServicing = LaunchAtLoginService()) {
        self.service = service
        self.status = service.status
    }

    var isEnabled: Bool {
        status.isEnabled
    }

    var canToggle: Bool {
        status.canToggle && !isUpdating
    }

    func refresh() {
        status = service.status
    }

    func setEnabled(_ enabled: Bool) {
        guard canToggle else {
            refresh()
            return
        }

        isUpdating = true
        errorMessage = nil
        defer { isUpdating = false }

        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }
}
