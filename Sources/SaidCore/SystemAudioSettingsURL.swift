import Foundation

public enum SystemAudioSettingsURL {
    public static let absoluteString =
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AudioCapture"

    public static let url = URL(string: absoluteString)!
}
