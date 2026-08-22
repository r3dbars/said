import SaidCore
import SwiftUI

struct CaptionView: View {
    @ObservedObject var model: AppModel
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text("\(Text(model.committedText).foregroundStyle(.primary))\(Text(model.tentativeText).foregroundStyle(.secondary))")
                .font(.system(size: model.captionTextSize.pointSize, weight: .semibold, design: .rounded))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel(model.committedText + model.tentativeText)

            if model.isPlacementMode {
                HStack(spacing: 10) {
                    Text("Drag captions where you want them.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Done", action: onDone)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 17)
        .frame(width: 760, height: 126)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
        .preferredColorScheme(.dark)
    }
}
