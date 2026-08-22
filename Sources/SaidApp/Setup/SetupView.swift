import SwiftUI

struct SetupView: View {
    @ObservedObject var model: AppModel
    let onPreview: () -> Void
    let onStartAudio: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Live captions for anything your Mac plays.")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Audio stays on this Mac. Captions disappear when Said quits.")
                    .foregroundStyle(.secondary)
            }

            SetupRow(
                symbol: "speaker.wave.2.fill",
                title: "System Audio",
                status: systemAudioStatus,
                explanation: "Said uses macOS System Audio Recording Only. It cannot capture screen pixels or your microphone."
            )
            if model.captureState == .capturing {
                ProgressView(value: model.audioLevel)
                    .progressViewStyle(.linear)
                    .accessibilityLabel("System audio level")
            }
            SetupRow(
                symbol: "waveform",
                title: "Speech Model",
                status: speechModelStatus,
                explanation: "A local English speech model is downloaded once. After that, captions work offline."
            )
            if case let .downloading(received, total) = model.modelState {
                VStack(alignment: .leading, spacing: 5) {
                    ProgressView(value: model.modelState.progress ?? 0)
                        .progressViewStyle(.linear)
                    Text("\(formatBytes(received)) of \(formatBytes(total))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("Hear. Read. Gone.")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack {
                    if shouldOfferSystemSettings {
                        Button("Open System Settings") {
                            model.openSystemAudioSettings()
                        }
                    }
                    if shouldOfferDiagnostics {
                        Button("Diagnostics…") { model.openDiagnostics() }
                    }
                    if !shouldOfferDiagnostics {
                        Button("Preview Captions", action: onPreview)
                    }
                    Button(primaryActionTitle, action: onStartAudio)
                        .buttonStyle(.borderedProminent)
                        .disabled(isPrimaryActionDisabled)
                }
                .controlSize(.large)
            }
        }
        .padding(28)
        .frame(width: 560)
    }

    private var speechModelStatus: String {
        switch model.modelState {
        case .checking: "Checking"
        case .notDownloaded: "Not downloaded"
        case .downloading: "Downloading"
        case .verifying: "Verifying"
        case .ready: "Ready"
        case .failed(.verificationFailed): "Verification failed"
        case .failed: "Needs retry"
        }
    }

    private var primaryActionTitle: String {
        switch model.modelState {
        case .ready: "Start Captions"
        case .failed: "Retry Setup"
        default: "Set Up Said"
        }
    }

    private var isPrimaryActionDisabled: Bool {
        switch model.modelState {
        case .checking, .downloading, .verifying: true
        default: model.captureState == .preparing || model.captureState == .starting || model.captureState == .capturing
        }
    }

    private var shouldOfferSystemSettings: Bool {
        if case .failed(.permissionDenied) = model.captureState { return true }
        return false
    }

    private var shouldOfferDiagnostics: Bool {
        if case .failed = model.captureState { return true }
        if case .failed = model.modelState { return true }
        return false
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private var systemAudioStatus: String {
        switch model.captureState {
        case .idle: "Needs permission"
        case .preparing: "Waiting for macOS"
        case .starting: "Starting"
        case .capturing: "Ready"
        case .recovering: "Restarting"
        case .stopping: "Stopping"
        case .failed(.permissionDenied): "Permission denied"
        case .failed: "Needs retry"
        }
    }
}

private struct SetupRow: View {
    let symbol: String
    let title: String
    let status: String
    let explanation: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .frame(width: 28)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    Text(status)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
