import AppKit
import Foundation
import SaidCore
import SaidModel

@MainActor
final class ModelLifecycleController {
    var onReady: ((URL) -> Void)?

    private let appModel: AppModel
    private let manager: ModelManager
    private var resolvedModelURL: URL?
    private var operationTask: Task<Void, Never>?

    init(appModel: AppModel, manager: ModelManager = ModelManager()) {
        self.appModel = appModel
        self.manager = manager
    }

    func prepareForLaunch() {
        operationTask?.cancel()
        appModel.modelState = .checking
        operationTask = Task { [weak self] in
            guard let self else { return }
            if await manager.validateInstalledModel() {
                let url = await manager.installedModelURL
                becomeReady(at: url, startCaptions: true)
                return
            }
            let developmentURL = AppPaths.developmentModelURL
            if FileManager.default.fileExists(atPath: developmentURL.path),
               await manager.validateModel(at: developmentURL) {
                becomeReady(at: developmentURL, startCaptions: true)
                return
            }
            resolvedModelURL = nil
            appModel.modelState = .notDownloaded
        }
    }

    func performPrimaryAction() {
        if appModel.modelState == .ready, let resolvedModelURL {
            onReady?(resolvedModelURL)
            return
        }
        install(force: false, startCaptions: true)
    }

    func reinstall() {
        install(force: true, startCaptions: true)
    }

    func remove() {
        operationTask?.cancel()
        operationTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await manager.remove()
                resolvedModelURL = nil
                appModel.modelState = .notDownloaded
            } catch {
                appModel.modelState = .failed(.installationFailed)
            }
        }
    }

    func revealInFinder() {
        Task {
            let url = await manager.store.modelDirectory
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private func install(force: Bool, startCaptions: Bool) {
        if operationTask != nil, operationTask?.isCancelled != true {
            switch appModel.modelState {
            case .checking, .downloading, .verifying: return
            default: break
            }
        }
        operationTask?.cancel()
        operationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let url = try await manager.install(force: force) { [weak self] state in
                    Task { @MainActor in self?.appModel.modelState = state }
                }
                becomeReady(at: url, startCaptions: startCaptions)
            } catch {
                if !Task.isCancelled, case .failed = appModel.modelState {
                    return
                }
                if !Task.isCancelled { appModel.modelState = .failed(.downloadFailed) }
            }
        }
    }

    private func becomeReady(at url: URL, startCaptions: Bool) {
        resolvedModelURL = url
        appModel.modelState = .ready
        operationTask = nil
        if startCaptions { onReady?(url) }
    }
}
