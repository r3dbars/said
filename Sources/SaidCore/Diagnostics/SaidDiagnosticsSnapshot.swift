public struct SaidDiagnosticsSnapshot: Equatable, Sendable {
    public let appVersion: String
    public let buildVersion: String
    public let operatingSystemVersion: String
    public let architecture: String
    public let modelState: ModelState
    public let captureState: CaptureState
    public let modelRevision: String
    public let modelHashPrefix: String

    public init(
        appVersion: String,
        buildVersion: String,
        operatingSystemVersion: String,
        architecture: String,
        modelState: ModelState,
        captureState: CaptureState,
        modelRevision: String,
        modelHashPrefix: String
    ) {
        self.appVersion = appVersion
        self.buildVersion = buildVersion
        self.operatingSystemVersion = operatingSystemVersion
        self.architecture = architecture
        self.modelState = modelState
        self.captureState = captureState
        self.modelRevision = modelRevision
        self.modelHashPrefix = modelHashPrefix
    }

    public var text: String {
        """
        Said diagnostics
        App version: \(appVersion) (\(buildVersion))
        macOS: \(operatingSystemVersion)
        Architecture: \(architecture)
        Model state: \(modelState.diagnosticName)
        Capture state: \(captureState.diagnosticName)
        Model revision: \(modelRevision)
        Model hash prefix: \(modelHashPrefix)

        This report excludes audio, captions, hypotheses, application names,
        window titles, URLs, usernames, and file paths.
        """
    }
}

public extension ModelState {
    var diagnosticName: String {
        switch self {
        case .checking: "checking"
        case .notDownloaded: "not_downloaded"
        case let .downloading(received, total): "downloading_\(received)_of_\(total)_bytes"
        case .verifying: "verifying"
        case .ready: "ready"
        case let .failed(failure): "failed_\(failure.rawValue)"
        }
    }
}

public extension CaptureState {
    var diagnosticName: String {
        switch self {
        case .idle: "idle"
        case .preparing: "preparing"
        case .starting: "starting"
        case .capturing: "capturing"
        case let .recovering(attempt): "recovering_attempt_\(attempt)"
        case .stopping: "stopping"
        case let .failed(failure): "failed_\(failure.rawValue)"
        }
    }
}
