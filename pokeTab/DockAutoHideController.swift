import AppKit
import Combine

@MainActor
final class DockAutoHideController: ObservableObject {
    static let shared = DockAutoHideController()

    @Published private(set) var errorMessage: String?

    private let ownershipKey = "customDockChangedSystemAutohide.v1"
    private var desiredEnabled = false
    private var updateTask: Task<Void, Never>?

    private init() {}

    func sync(enabled: Bool) {
        desiredEnabled = enabled
        guard updateTask == nil else { return }
        updateTask = Task { [weak self] in
            guard let self else { return }
            while true {
                let enabled = self.desiredEnabled
                let wasChangedByApp = UserDefaults.standard.bool(forKey: self.ownershipKey)
                let result = await Task.detached {
                    Self.apply(enabled: enabled, wasChangedByApp: wasChangedByApp)
                }.value

                switch result {
                case .success(let changedByApp):
                    UserDefaults.standard.set(changedByApp, forKey: self.ownershipKey)
                    self.errorMessage = nil
                case .failure:
                    self.errorMessage = NSLocalizedString("Não foi possível alterar a Dock do macOS. Permita a Automação para Eventos do Sistema ou ative a ocultação em Ajustes do Sistema → Mesa e Dock.", comment: "Dock auto-hide error")
                }
                if self.desiredEnabled == enabled { break }
            }
            self.updateTask = nil
        }
    }

    nonisolated private static func apply(enabled: Bool, wasChangedByApp: Bool) -> Result<Bool, DockScriptError> {
        if !enabled && !wasChangedByApp { return .success(false) }

        let source = """
        tell application id "com.apple.systemevents"
            set previouslyHidden to autohide of dock preferences
            if \(enabled ? "true" : "false") then
                if not previouslyHidden then set autohide of dock preferences to true
            else
                if previouslyHidden then set autohide of dock preferences to false
            end if
            return {previouslyHidden, autohide of dock preferences}
        end tell
        """

        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return .failure(DockScriptError()) }
        let result = script.executeAndReturnError(&error)
        guard error == nil,
              let previouslyHidden = result.atIndex(1),
              let nowHidden = result.atIndex(2),
              nowHidden.booleanValue == enabled else { return .failure(DockScriptError()) }
        return .success(enabled && (wasChangedByApp || !previouslyHidden.booleanValue))
    }
}

private struct DockScriptError: Error {}
