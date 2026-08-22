import Combine
import Foundation
import SaidCore
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    @Published var committedText = ""
    @Published var tentativeText = ""
    @Published var isPlacementMode = false
    @Published var captureState: CaptureState = .idle
    @Published var audioLevel = 0.0
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginError: String?
    @Published var captionTextSize: CaptionTextSize {
        didSet { defaults.set(captionTextSize.rawValue, forKey: Keys.captionTextSize) }
    }

    var onResetPosition: (() -> Void)?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        captionTextSize = CaptionTextSize(
            rawValue: defaults.string(forKey: Keys.captionTextSize) ?? ""
        ) ?? .standard
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }

    func resetCaptionPosition() {
        onResetPosition?()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            launchAtLoginError = nil
        } catch {
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            launchAtLoginError = "Launch at Login could not be changed."
        }
    }

    private enum Keys {
        static let captionTextSize = "captionTextSize"
    }
}
