import AppKit
import SaidCore
import SwiftUI

struct CaptionView: View {
    @ObservedObject var model: AppModel
    let onDone: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(spacing: 8) {
            if model.captionControlsMode.isVisible,
               model.captionToolbarPlacement == .above {
                controlBar
            }
            captionCard
            if model.captionControlsMode.isVisible,
               model.captionToolbarPlacement == .below {
                controlBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        .onExitCommand {
            if model.captionToolbarSection != .none {
                model.captionToolbarSection = .none
            } else {
                onDone()
            }
        }
    }

    private var controlBar: some View {
        CaptionToolbarView(model: model)
            .opacity(model.captionToolbarOpacity)
    }

    private var captionCard: some View {
        captionRows
            .padding(.horizontal, CaptionPanelLayout.horizontalPadding(for: model.captionTextSize))
            .padding(.vertical, CaptionPanelLayout.verticalPadding(for: model.captionTextSize))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { captionSurface }
            .overlay {
                captionShape
                    .stroke(
                        .white.opacity(contrast == .increased ? 0.42 : 0.12),
                        lineWidth: 1
                    )
            }
    }

    private var captionRows: some View {
        VStack(alignment: .leading, spacing: 4) {
            if model.captionWindow.lines.isEmpty,
               let placeholder = model.captionPlaceholderText {
                Text(placeholder)
                    .foregroundStyle(captionColor.opacity(0.46))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(model.captionWindow.lines) { line in
                    Text("\(Text(line.committed).foregroundStyle(captionColor))\(Text(line.tentative).foregroundStyle(captionColor.opacity(0.64)))")
                        .lineLimit(1)
                        .truncationMode(.head)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .font(model.captionFontStyle.font(size: model.captionTextSize.pointSize))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.visibleCaptionText.isEmpty
            ? model.captionPlaceholderText ?? ""
            : model.visibleCaptionText)
    }

    @ViewBuilder
    private var captionSurface: some View {
        let shape = captionShape
        if reduceTransparency || contrast == .increased {
            shape.fill(Color.black)
        } else {
            shape.fill(Color(red: 0.07, green: 0.075, blue: 0.085).opacity(model.captionBackgroundOpacity))
        }
    }

    private var captionShape: ProportionalCaptionShape { ProportionalCaptionShape() }

    private var captionColor: Color { model.captionTextColor.color }
}

/// Use the rendered height so the curves retain their proportions during resizing.
private struct ProportionalCaptionShape: Shape {
    func path(in rect: CGRect) -> Path {
        RoundedRectangle(
            cornerRadius: rect.height * CaptionToolbarLayout.cornerRadius / CaptionToolbarLayout.height,
            style: .continuous
        ).path(in: rect)
    }
}
