import SaidCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    let showPrivacy: Bool

    var body: some View {
        Form {
            if showPrivacy {
                Section("What Said hears") {
                    Text("Audio playing through your Mac while Said is open.")
                }
                Section("What Said does not capture") {
                    Text("Your microphone, camera, screen pixels, keyboard, clipboard, files, or browser history.")
                }
                Section("What leaves your Mac") {
                    Text("Nothing from your audio or captions. Said connects only to download its speech model and check for app updates.")
                }
                Section("What is saved") {
                    Text("The speech model and your app settings. Said does not save audio or caption text.")
                }
            } else {
                Section("Captions") {
                    Picker("Text size", selection: $model.captionTextSize) {
                        ForEach(CaptionTextSize.allCases, id: \.self) { size in
                            Text(size.title).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    Button("Reset Caption Position") { model.resetCaptionPosition() }
                }
                Section("General") {
                    Toggle(
                        "Launch Said at login",
                        isOn: Binding(
                            get: { model.launchAtLoginEnabled },
                            set: { model.setLaunchAtLogin($0) }
                        )
                    )
                    if let error = model.launchAtLoginError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Storage") {
                    LabeledContent("Speech model", value: "Parakeet Unified English")
                    LabeledContent("Approximate size", value: "731 MB")
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .frame(width: 500, height: showPrivacy ? 460 : 330)
    }
}
