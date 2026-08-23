import Combine
import Foundation
import SaidCore
import SaidModel
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    @Published var captionWindow = CaptionWindow.empty
    @Published var captionControlsMode = CaptionControlsMode.hidden
    @Published var captionToolbarPlacement = CaptionToolbarPlacement.above
    @Published var captureState: CaptureState = .idle
    @Published var modelState: ModelState = .checking
    @Published private(set) var captionsEnabled: Bool {
        didSet { defaults.set(captionsEnabled, forKey: Keys.captionsEnabled) }
    }
    @Published var audioLevel = 0.0
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginError: String?
    @Published var captionScale: CaptionScale {
        didSet { defaults.set(captionScale.rawValue, forKey: Keys.captionScale) }
    }
    @Published var captionFontStyle: CaptionFontStyle {
        didSet { defaults.set(captionFontStyle.rawValue, forKey: Keys.captionFontStyle) }
    }
    @Published var captionTextColor: CaptionTextColor {
        didSet { defaults.set(captionTextColor.rawValue, forKey: Keys.captionTextColor) }
    }
    var captionTextSize: CaptionTextSize { captionScale.textSize }
    var captionPanelWidth: CaptionPanelWidth { captionScale.panelWidth }

    var onResetCaptionLayout: (() -> Void)?
    var onReinstallModel: (() -> Void)?
    var onRemoveModel: (() -> Void)?
    var onRevealModel: (() -> Void)?
    var onOpenLicenses: (() -> Void)?
    var onOpenPrivacyDocument: (() -> Void)?
    var onCheckForUpdates: (() -> Void)?
    var onOpenDiagnostics: (() -> Void)?
    var onOpenSystemAudioSettings: (() -> Void)?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        captionsEnabled = defaults.object(forKey: Keys.captionsEnabled) as? Bool ?? true
        let storedTextSize = CaptionTextSize(
            rawValue: defaults.string(forKey: Keys.captionTextSize) ?? ""
        ) ?? .standard
        captionFontStyle = CaptionFontStyle(
            rawValue: defaults.string(forKey: Keys.captionFontStyle) ?? ""
        ) ?? .rounded
        captionTextColor = CaptionTextColor(
            rawValue: defaults.string(forKey: Keys.captionTextColor) ?? ""
        ) ?? .white
        let storedPanelWidth: CaptionPanelWidth
        if let stored = defaults.string(forKey: Keys.captionPanelWidth),
           let width = CaptionPanelWidth(rawValue: stored) {
            storedPanelWidth = width
        } else if defaults.object(forKey: Keys.legacyCaptionWidth) != nil {
            storedPanelWidth = .nearest(to: defaults.double(forKey: Keys.legacyCaptionWidth))
        } else {
            storedPanelWidth = .medium
        }
        captionScale = CaptionScale(
            rawValue: defaults.string(forKey: Keys.captionScale) ?? ""
        ) ?? .nearest(textSize: storedTextSize, panelWidth: storedPanelWidth)
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        defaults.set(captionScale.rawValue, forKey: Keys.captionScale)
    }

    func resetCaptionLayout() {
        onResetCaptionLayout?()
    }

    func setCaptionsEnabled(_ enabled: Bool) {
        captionsEnabled = enabled
    }

    func reinstallModel() { onReinstallModel?() }
    func removeModel() { onRemoveModel?() }
    func revealModel() { onRevealModel?() }
    func openLicenses() { onOpenLicenses?() }
    func openPrivacyDocument() { onOpenPrivacyDocument?() }
    func checkForUpdates() { onCheckForUpdates?() }
    func openDiagnostics() { onOpenDiagnostics?() }
    func openSystemAudioSettings() { onOpenSystemAudioSettings?() }

    var diagnosticsSnapshot: SaidDiagnosticsSnapshot {
        let info = Bundle.main.infoDictionary ?? [:]
        return SaidDiagnosticsSnapshot(
            appVersion: info["CFBundleShortVersionString"] as? String ?? "Development",
            buildVersion: info["CFBundleVersion"] as? String ?? "Development",
            operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            architecture: "arm64",
            modelState: modelState,
            captureState: captureState,
            modelRevision: ModelManifest.saidEnglishQ8.revision,
            modelHashPrefix: String(ModelManifest.saidEnglishQ8.sha256.prefix(12))
        )
    }

    var visibleCaptionText: String { captionWindow.text }
    var captionPlaceholderText: String? {
        CaptionSurfaceText.placeholder(
            model: modelState,
            capture: captureState,
            captionsEnabled: captionsEnabled
        )
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
        static let captionsEnabled = "captionsEnabled"
        static let captionScale = "captionScale"
        static let captionTextSize = "captionTextSize"
        static let captionFontStyle = "captionFontStyle"
        static let captionTextColor = "captionTextColor"
        static let captionPanelWidth = "captionPanelWidth"
        static let legacyCaptionWidth = "captionWidth"
    }
}
