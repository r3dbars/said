import SaidCore
import SwiftUI

extension CaptionFontStyle {
    func font(size: Double) -> Font {
        Font(CaptionFonts.captionFont(for: self, size: size))
    }

}

extension CaptionTextColor {
    var color: Color {
        switch self {
        case .white: .white
        case .yellow: Color(red: 1.0, green: 0.86, blue: 0.36)
        case .cyan: Color(red: 0.43, green: 0.91, blue: 1.0)
        case .mint: Color(red: 0.55, green: 0.91, blue: 0.72)
        case .lavender: Color(red: 0.79, green: 0.71, blue: 1.0)
        }
    }
}
