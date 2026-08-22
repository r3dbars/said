import SaidCore
import SwiftUI

struct CaptionView: View {
    @ObservedObject var model: AppModel
    let onDone: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(spacing: 10) {
            captionRows

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
        .frame(width: 760, height: model.captionTextSize.panelHeight)
        .background { captionSurface }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(contrast == .increased ? 0.42 : 0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
        .preferredColorScheme(.dark)
    }

    private var captionRows: some View {
        VStack(alignment: .leading, spacing: 4) {
            if model.captionWindow.lines.count < 2 {
                Spacer(minLength: 0)
            }
            ForEach(model.captionWindow.lines) { line in
                Text("\(Text(line.committed).foregroundStyle(.primary))\(Text(line.tentative).foregroundStyle(.secondary))")
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.system(size: model.captionTextSize.pointSize, weight: .semibold, design: .rounded))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.visibleCaptionText)
    }

    @ViewBuilder
    private var captionSurface: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        if reduceTransparency || contrast == .increased {
            shape.fill(Color.black)
        } else {
            shape.fill(.ultraThickMaterial)
        }
    }
}
