import AppKit
import SaidCore
import SwiftUI

struct CaptionView: View {
    @ObservedObject var model: AppModel
    let onDone: () -> Void
    let onResize: (CGFloat) -> Void
    let onResizeEnded: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(spacing: 8) {
            if model.captionControlsMode.isVisible { controlBar }
            captionCard
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
    }

    private var controlBar: some View {
        HStack(spacing: 7) {
            Image(systemName: "hand.draw")
                .foregroundStyle(.secondary)
                .help("Drag the bar or caption strip to move it")

            Divider().frame(height: 18)
            sizeControls
            Divider().frame(height: 18)
            fontMenu
            Divider().frame(height: 18)
            colorControls
            Spacer(minLength: 2)
            resizeHandle
            if model.captionControlsMode.showsDoneButton {
                Button("Done", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 48)
        .background { controlSurface }
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(.white.opacity(contrast == .increased ? 0.42 : 0.11), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 12, y: 5)
        .accessibilityElement(children: .contain)
    }

    private var captionCard: some View {
        captionRows
            .padding(.horizontal, 24)
            .padding(.vertical, 17)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { captionSurface }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        .white.opacity(contrast == .increased ? 0.42 : 0.12),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
    }

    private var captionRows: some View {
        VStack(alignment: .leading, spacing: 4) {
            if model.captionWindow.lines.count < 2 {
                Spacer(minLength: 0)
            }
            ForEach(model.captionWindow.lines) { line in
                Text("\(Text(line.committed).foregroundStyle(captionColor))\(Text(line.tentative).foregroundStyle(captionColor.opacity(0.64)))")
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(
            .system(
                size: model.captionTextSize.pointSize,
                weight: .semibold,
                design: model.captionFontStyle.fontDesign
            )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.visibleCaptionText)
    }

    private var sizeControls: some View {
        HStack(spacing: 5) {
            Button { model.decreaseCaptionTextSize() } label: {
                Image(systemName: "textformat.size.smaller")
            }
            .disabled(model.captionTextSize == .small)
            .help("Smaller captions")
            .accessibilityLabel("Smaller captions")

            Text("\(Int(model.captionTextSize.pointSize))")
                .font(.caption.monospacedDigit().weight(.semibold))
                .frame(minWidth: 22)
                .accessibilityLabel("\(Int(model.captionTextSize.pointSize)) point captions")

            Button { model.increaseCaptionTextSize() } label: {
                Image(systemName: "textformat.size.larger")
            }
            .disabled(model.captionTextSize == .large)
            .help("Larger captions")
            .accessibilityLabel("Larger captions")
        }
        .buttonStyle(.plain)
    }

    private var fontMenu: some View {
        Button {
            model.captionFontStyle = model.captionFontStyle.next
        } label: {
            HStack(spacing: 4) {
                Text("Aa")
                Text(model.captionFontStyle.title)
                    .lineLimit(1)
            }
            .font(.caption.weight(.semibold))
        }
        .buttonStyle(.plain)
        .fixedSize()
        .help("Change caption font")
        .accessibilityLabel("Caption font, \(model.captionFontStyle.title)")
        .accessibilityHint("Cycles through Rounded, Sans, and Serif")
    }

    private var colorControls: some View {
        HStack(spacing: 5) {
            ForEach(CaptionTextColor.allCases, id: \.self) { choice in
                Button { model.captionTextColor = choice } label: {
                    Circle()
                        .fill(choice.color)
                        .frame(width: 14, height: 14)
                        .overlay {
                            if choice == model.captionTextColor {
                                Circle().stroke(.white.opacity(0.9), lineWidth: 2)
                                    .padding(-3)
                            }
                        }
                }
                .buttonStyle(.plain)
                .help(choice.title)
                .accessibilityLabel("\(choice.title) caption text")
                .accessibilityValue(choice == model.captionTextColor ? "Selected" : "")
            }
        }
    }

    private var resizeHandle: some View {
        Image(systemName: "arrow.left.and.right")
            .font(.caption.weight(.semibold))
            .frame(width: 28, height: 26)
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { onResize($0.translation.width) }
                    .onEnded { _ in onResizeEnded() }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
            .help("Drag left or right to resize captions")
            .accessibilityLabel("Resize captions")
            .accessibilityHint("Drag left or right")
    }

    @ViewBuilder
    private var captionSurface: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        if reduceTransparency || contrast == .increased {
            shape.fill(Color.black)
        } else {
            ZStack {
                shape.fill(.ultraThickMaterial)
                shape.fill(Color(red: 0.07, green: 0.075, blue: 0.085).opacity(0.72))
            }
        }
    }

    @ViewBuilder
    private var controlSurface: some View {
        let shape = RoundedRectangle(cornerRadius: 15, style: .continuous)
        if reduceTransparency || contrast == .increased {
            shape.fill(Color(red: 0.10, green: 0.10, blue: 0.11))
        } else {
            ZStack {
                shape.fill(.thickMaterial)
                shape.fill(Color(red: 0.10, green: 0.10, blue: 0.11).opacity(0.82))
            }
        }
    }

    private var captionColor: Color { model.captionTextColor.color }
}

private extension CaptionFontStyle {
    var fontDesign: Font.Design {
        switch self {
        case .rounded: .rounded
        case .sans: .default
        case .serif: .serif
        }
    }
}

private extension CaptionTextColor {
    var color: Color {
        switch self {
        case .white: .white
        case .yellow: Color(red: 1.0, green: 0.86, blue: 0.36)
        case .cyan: Color(red: 0.43, green: 0.91, blue: 1.0)
        }
    }
}
