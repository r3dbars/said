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
    }

    private var controlBar: some View {
        HStack(spacing: 7) {
            Image(systemName: "hand.draw")
                .foregroundStyle(.secondary)
                .help("Drag the bar or caption strip to move it")

            Divider().frame(height: 18)
            scaleControl
            Divider().frame(height: 18)
            fontMenu
            Divider().frame(height: 18)
            colorControls
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
    }

    private var captionRows: some View {
        VStack(alignment: .center, spacing: 4) {
            if model.captionWindow.lines.isEmpty,
               let placeholder = model.captionPlaceholderText {
                Text(placeholder)
                    .foregroundStyle(captionColor.opacity(0.46))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(model.captionWindow.lines) { line in
                    Text("\(Text(line.committed).foregroundStyle(captionColor))\(Text(line.tentative).foregroundStyle(captionColor.opacity(0.64)))")
                        .lineLimit(1)
                        .truncationMode(.head)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .font(
            .system(
                size: model.captionTextSize.pointSize,
                weight: model.captionFontStyle.fontWeight,
                design: model.captionFontStyle.fontDesign
            )
        )
        .fontWidth(model.captionFontStyle.fontWidth)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.visibleCaptionText.isEmpty
            ? model.captionPlaceholderText ?? ""
            : model.visibleCaptionText)
    }

    private var scaleControl: some View {
        Button { model.captionScale = model.captionScale.next } label: {
            HStack(spacing: 5) {
                Text(model.captionScale.title)
                    .font(.caption.monospaced().weight(.bold))
                Text("\(Int(model.captionTextSize.pointSize))px")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 7)
            .frame(height: 26)
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .help(
            "Caption size: \(model.captionScale.accessibilityTitle), "
                + "\(Int(model.captionTextSize.pointSize)) point text. Click to change."
        )
        .accessibilityLabel("Caption size")
        .accessibilityValue(
            "\(model.captionScale.accessibilityTitle), "
                + "\(Int(model.captionTextSize.pointSize)) point text"
        )
        .accessibilityHint("Cycles through Extra Small, Small, Medium, Large, and Extra Large")
    }

    private var fontMenu: some View {
        Button {
            model.captionFontStyle = model.captionFontStyle.next
        } label: {
            HStack(spacing: 4) {
                Text("Aa")
                    .font(
                        .system(
                            size: 12,
                            weight: model.captionFontStyle.fontWeight,
                            design: model.captionFontStyle.fontDesign
                        )
                    )
                    .fontWidth(model.captionFontStyle.fontWidth)
                Text(model.captionFontStyle.title)
                    .lineLimit(1)
            }
            .font(.caption.weight(.semibold))
        }
        .buttonStyle(.plain)
        .fixedSize()
        .help("Change caption font")
        .accessibilityLabel("Caption font, \(model.captionFontStyle.title)")
        .accessibilityHint("Cycles through Rounded, Sans, Serif, Mono, and Block")
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

    @ViewBuilder
    private var captionSurface: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        if reduceTransparency || contrast == .increased {
            shape.fill(Color.black)
        } else {
            shape.fill(Color(red: 0.07, green: 0.075, blue: 0.085).opacity(0.96))
        }
    }

    @ViewBuilder
    private var controlSurface: some View {
        let shape = RoundedRectangle(cornerRadius: 15, style: .continuous)
        if reduceTransparency || contrast == .increased {
            shape.fill(Color(red: 0.10, green: 0.10, blue: 0.11))
        } else {
            shape.fill(Color(red: 0.10, green: 0.10, blue: 0.11).opacity(0.96))
        }
    }

    private var captionColor: Color { model.captionTextColor.color }
}

private extension CaptionFontStyle {
    var fontDesign: Font.Design {
        switch self {
        case .rounded: .rounded
        case .sans, .block: .default
        case .serif: .serif
        case .mono: .monospaced
        }
    }

    var fontWeight: Font.Weight {
        switch self {
        case .block: .black
        case .rounded, .sans, .serif, .mono: .semibold
        }
    }

    var fontWidth: Font.Width {
        switch self {
        case .mono: .condensed
        case .rounded, .sans, .serif, .block: .standard
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
