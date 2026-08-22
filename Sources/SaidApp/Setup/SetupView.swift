import SwiftUI

struct SetupView: View {
    let onPreview: () -> Void

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
                status: "Coming next",
                explanation: "Said will use an audio-only macOS capture stream. It will not capture screen pixels or your microphone."
            )
            SetupRow(
                symbol: "waveform",
                title: "Speech Model",
                status: "Verified locally",
                explanation: "The local English speech model is installed for this development build."
            )

            HStack {
                Text("Hear. Read. Gone.")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Preview Captions", action: onPreview)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .padding(28)
        .frame(width: 560)
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
