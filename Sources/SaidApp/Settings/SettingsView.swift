import SaidCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    let showPrivacy: Bool
    var showDiagnostics = false
    @State private var confirmRemoval = false

    var body: some View {
        Form {
            if showDiagnostics {
                Section("Local diagnostics") {
                    Text(model.diagnosticsSnapshot.text)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("This report stays on your Mac unless you choose to share it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if showPrivacy {
                Section("What Said hears") {
                    Text("Audio playing through your Mac while Said is open.")
                }
                Section("What Said does not capture") {
                    Text("Your microphone, camera, screen pixels, keyboard, clipboard, files, or browser history.")
                }
                Section("What leaves your Mac") {
                    Text("Nothing from your audio or captions. This alpha connects only to download its speech model.")
                }
                Section("What is saved") {
                    Text("The speech model and your app settings. Said does not save audio or caption text.")
                    Button("Open Complete Privacy Document") {
                        model.openPrivacyDocument()
                    }
                }
            } else {
                Section("Captions") {
                    Picker("Caption size", selection: $model.captionScale) {
                        ForEach(CaptionScale.allCases, id: \.self) { scale in
                            Text(scale.title).tag(scale)
                        }
                    }
                    .pickerStyle(.segmented)
                    Button("Reset Caption Layout") { model.resetCaptionLayout() }
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
                    LabeledContent("Speech model", value: "English speech model")
                    LabeledContent("Approximate size", value: "731 MB")
                    HStack {
                        Button("Reinstall Model…") { model.reinstallModel() }
                        Button("Reveal in Finder") { model.revealModel() }
                        Spacer()
                        Button("Remove Local Model…", role: .destructive) {
                            confirmRemoval = true
                        }
                    }
                }
                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    HStack {
                        Button("Open Source Licenses") { model.openLicenses() }
                        Button("Diagnostics…") { model.openDiagnostics() }
                        Button("Check for Updates") { model.checkForUpdates() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .frame(width: 500, height: showPrivacy ? 480 : 420)
        .confirmationDialog(
            "Remove the local speech model?",
            isPresented: $confirmRemoval,
            titleVisibility: .visible
        ) {
            Button("Remove Model", role: .destructive) { model.removeModel() }
        } message: {
            Text("Said will need to download the model again before captions can start.")
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "Development"
    }
}
