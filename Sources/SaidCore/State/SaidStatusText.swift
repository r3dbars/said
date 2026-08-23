public enum SaidStatusText {
    public static func title(
        model: ModelState,
        capture: CaptureState,
        captionsEnabled: Bool = true
    ) -> String {
        guard captionsEnabled else { return "Captions are off" }
        switch model {
        case .checking:
            return "Checking speech model…"
        case .notDownloaded:
            return "Said needs setup"
        case .downloading:
            return "Downloading speech model…"
        case .verifying:
            return "Verifying speech model…"
        case .failed:
            return "Said needs attention"
        case .ready:
            return captureTitle(capture)
        }
    }

    private static func captureTitle(_ state: CaptureState) -> String {
        switch state {
        case .idle: "Ready locally"
        case .preparing: "Loading speech model…"
        case .starting: "Starting audio capture…"
        case .capturing: "Listening locally"
        case .recovering: "Restarting local captions…"
        case .stopping: "Stopping…"
        case .failed: "Said needs attention"
        }
    }
}

public enum CaptionSurfaceText {
    public static func placeholder(
        model: ModelState,
        capture: CaptureState,
        captionsEnabled: Bool
    ) -> String? {
        guard captionsEnabled else { return nil }
        guard case .ready = model else { return "Preparing captions…" }

        switch capture {
        case .idle:
            return "Captions are on"
        case .preparing, .starting:
            return "Starting captions…"
        case .capturing:
            return "Waiting for speech…"
        case .recovering:
            return "Reconnecting…"
        case .stopping:
            return "Stopping captions…"
        case .failed:
            return "Captions need attention"
        }
    }
}
