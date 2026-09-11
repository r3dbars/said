import SaidCore
import SwiftUI

struct CaptionToolbarView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        GeometryReader { geometry in
            let layout = CaptionToolbarLayout(
                captionWidth: geometry.size.width, section: model.captionToolbarSection
            )
            HStack(spacing: 6) {
                if layout.usesFocusedControls {
                    focusedControls
                } else {
                    sizeButton
                    separator
                    CaptionFontMenu(model: model)
                        .frame(width: 112, height: 32)
                    separator
                    colorButton
                    separator
                    opacityButton
                }
            }
            .padding(.horizontal, 12)
            .frame(width: layout.width, height: CaptionToolbarLayout.height)
            .background(Color(red: 0.10, green: 0.10, blue: 0.115),
                        in: RoundedRectangle(cornerRadius: CaptionToolbarLayout.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CaptionToolbarLayout.cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(contrast == .increased ? 0.5 : 0.12))
            }
            .offset(x: layout.offsetX)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18),
                       value: model.captionToolbarSection)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Caption appearance")
        }
        .frame(height: CaptionToolbarLayout.height)
    }

    @ViewBuilder private var focusedControls: some View {
        switch model.captionToolbarSection {
        case .size: sizeChoices
        case .color: colorChoices
        case .opacity:
            opacityButton
            opacitySlider
        case .none: EmptyView()
        }
    }

    private var separator: some View {
        Rectangle().fill(.white.opacity(0.13)).frame(width: 1, height: 16)
    }

    private var sizeButton: some View {
        Button { toggle(.size) } label: {
            Text("A").font(.system(size: 20, weight: .medium))
                .frame(width: 28, height: 32)
        }
        .buttonStyle(CaptionToolbarButtonStyle())
        .help("Caption size")
        .accessibilityLabel("Caption size")
        .accessibilityValue(model.captionScale.accessibilityTitle)
        .accessibilityHint("Show five text sizes")
    }

    private var sizeChoices: some View {
        HStack(spacing: 4) {
            ForEach(Array(CaptionScale.allCases.enumerated()), id: \.element) { index, choice in
                Button {
                    model.captionToolbarSection = .none
                    model.captionScale = choice
                } label: {
                    Text("A")
                        .font(.system(size: Double(12 + index * 3), weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(minWidth: 28, minHeight: 32)
                        .background(.white.opacity(choice == model.captionScale ? 0.16 : 0),
                                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(CaptionToolbarButtonStyle())
                .help(choice.accessibilityTitle)
                .accessibilityLabel("\(choice.accessibilityTitle) captions")
                .accessibilityValue(choice == model.captionScale ? "Selected" : "")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var colorButton: some View {
        Button { toggle(.color) } label: {
            swatch(model.captionTextColor, selected: false)
        }
        .buttonStyle(CaptionToolbarButtonStyle())
        .help("Caption color")
        .accessibilityLabel("Caption color")
        .accessibilityValue(model.captionTextColor.title)
        .accessibilityHint("Show five colors")
    }

    private var colorChoices: some View {
        HStack(spacing: 0) {
            ForEach(CaptionTextColor.allCases, id: \.self) { choice in
                Button {
                    model.captionTextColor = choice
                    model.captionToolbarSection = .none
                } label: {
                    swatch(choice, selected: choice == model.captionTextColor)
                }
                .buttonStyle(CaptionToolbarButtonStyle())
                .frame(maxWidth: .infinity)
                .help(choice.title)
                .accessibilityLabel("\(choice.title) caption text")
                .accessibilityValue(choice == model.captionTextColor ? "Selected" : "")
            }
        }
    }

    private func swatch(_ color: CaptionTextColor, selected: Bool) -> some View {
        Circle().fill(color.color).frame(width: 14, height: 14)
            .overlay {
                if selected { Circle().stroke(.white, lineWidth: 1.5).padding(-3) }
            }
            .frame(width: 28, height: 32)
            .contentShape(Rectangle())
    }

    private var opacityButton: some View {
        Button { toggle(.opacity) } label: {
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 17, weight: .regular))
                .frame(width: 28, height: 32)
        }
        .buttonStyle(CaptionToolbarButtonStyle())
        .help("Background opacity")
        .accessibilityLabel("Background opacity")
        .accessibilityValue("\(Int((model.captionBackgroundOpacity * 100).rounded())) percent")
        .accessibilityHint("Show opacity slider")
    }

    private var opacitySlider: some View {
        HStack(spacing: 8) {
            CaptionOpacitySlider(model: model)
                .frame(height: 24)
            Text("\(Int((model.captionBackgroundOpacity * 100).rounded()))%")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }

    private func toggle(_ section: CaptionToolbarSection) {
        model.captionToolbarSection = model.captionToolbarSection == section ? .none : section
    }
}

private struct CaptionToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.65 : 0.92))
            .background(.white.opacity(configuration.isPressed ? 0.1 : 0),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
    }
}
