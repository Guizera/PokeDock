import AppKit
import Combine
import SwiftUI

enum MusicProvider: String, CaseIterable, Identifiable {
    case spotify
    case appleMusic

    var id: String { rawValue }
    var title: String { self == .spotify ? "Spotify" : NSLocalizedString("Música", comment: "Apple Music provider") }
    var bundleID: String { self == .spotify ? "com.spotify.client" : "com.apple.Music" }
    var symbol: String { self == .spotify ? "music.note" : "music.note.list" }
}

struct MusicSnapshot {
    var track = ""
    var artist = ""
    var isPlaying = false
    var message: String?
}

private struct MusicScriptError: Error {
    let code: Int
}

@MainActor
final class MusicController: ObservableObject {
    static let shared = MusicController()
    @Published private(set) var snapshots: [MusicProvider: MusicSnapshot] = [:]
    @Published private(set) var connected: Set<MusicProvider> = []
    private var pending: Set<MusicProvider> = []

    private init() {
        connected = Set(MusicProvider.allCases.filter { UserDefaults.standard.bool(forKey: "musicConnected.\($0.rawValue).v1") })
    }

    func connect(_ provider: MusicProvider) { refresh(provider, requestingAccess: true) }

    func refresh(_ provider: MusicProvider, requestingAccess: Bool = false) {
        guard (connected.contains(provider) || requestingAccess), !pending.contains(provider) else { return }
        guard NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == provider.bundleID && !$0.isTerminated }) else {
            snapshots[provider] = MusicSnapshot(message: String(format: NSLocalizedString("Abra o %@", comment: "Open the music player"), provider.title))
            return
        }
        pending.insert(provider)
        let source = """
        tell application id "\(provider.bundleID)"
            set playbackState to player state as text
            if playbackState is "stopped" then return "stopped"
            try
                set songName to name of current track as text
                set artistName to artist of current track as text
                return playbackState & linefeed & songName & linefeed & artistName
            on error
                return playbackState
            end try
        end tell
        """
        Task.detached { [weak self] in
            let result = Self.runScript(source)
            await self?.completeRefresh(provider, result: result)
        }
    }

    func command(_ command: MusicCommand, for provider: MusicProvider) {
        guard connected.contains(provider), !pending.contains(provider) else { return }
        pending.insert(provider)
        let source = "tell application id \"\(provider.bundleID)\" to \(command.appleScript)"
        Task.detached { [weak self] in
            let result = Self.runScript(source)
            await self?.completeCommand(provider, result: result)
        }
    }

    private func completeRefresh(_ provider: MusicProvider, result: Result<String, MusicScriptError>) {
        pending.remove(provider)
        switch result {
        case .success(let output):
            let parts = output.components(separatedBy: "\n")
            snapshots[provider] = MusicSnapshot(
                track: parts.count > 1 ? parts[1] : "",
                artist: parts.count > 2 ? parts[2] : "",
                isPlaying: parts.first == "playing",
                message: parts.first == "stopped" ? NSLocalizedString("Nada tocando", comment: "Nothing playing") : nil
            )
            connected.insert(provider)
            UserDefaults.standard.set(true, forKey: "musicConnected.\(provider.rawValue).v1")
        case .failure(let error):
            snapshots[provider] = MusicSnapshot(message: NSLocalizedString(error.code == -1743 ? "Permissão negada" : "Controle indisponível", comment: "Music control error"))
            if error.code == -1743 {
                connected.remove(provider)
                UserDefaults.standard.set(false, forKey: "musicConnected.\(provider.rawValue).v1")
            }
        }
    }

    private func completeCommand(_ provider: MusicProvider, result: Result<String, MusicScriptError>) {
        pending.remove(provider)
        if case .failure(let error) = result {
            snapshots[provider] = MusicSnapshot(message: NSLocalizedString(error.code == -1743 ? "Permissão negada" : "Controle indisponível", comment: "Music control error"))
            if error.code == -1743 {
                connected.remove(provider)
                UserDefaults.standard.set(false, forKey: "musicConnected.\(provider.rawValue).v1")
            }
        } else {
            refresh(provider)
        }
    }

    nonisolated private static func runScript(_ source: String) -> Result<String, MusicScriptError> {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            return .failure(MusicScriptError(code: -1))
        }
        let value = script.executeAndReturnError(&error)
        if error != nil {
            return .failure(MusicScriptError(code: error?["NSAppleScriptErrorNumber"] as? Int ?? -1))
        }
        return .success(value.stringValue ?? "")
    }
}

enum MusicCommand {
    case previous, playPause, next
    var appleScript: String {
        switch self {
        case .previous: "previous track"
        case .playPause: "playpause"
        case .next: "next track"
        }
    }
}

struct MusicDockWidgetView: View {
    let provider: MusicProvider
    let isPreview: Bool
    @ObservedObject private var music = MusicController.shared
    @ObservedObject private var dock = CustomDockController.shared

    private var isRunning: Bool {
        dock.runningApps.contains { $0.application.bundleIdentifier == provider.bundleID }
    }

    private var snapshot: MusicSnapshot { music.snapshots[provider] ?? MusicSnapshot(message: NSLocalizedString("Nada tocando", comment: "Nothing playing")) }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: provider.symbol)
                .font(.title2)
                .frame(width: 25)
            VStack(alignment: .leading, spacing: 3) {
                Text(provider.title).font(.caption2.bold()).opacity(0.8)
                if !isRunning {
                    Button("Abrir app") { openProvider() }
                        .disabled(isPreview)
                } else if !music.connected.contains(provider) {
                    Button("Conectar") { music.connect(provider) }
                        .disabled(isPreview)
                } else {
                    Text(snapshot.track.isEmpty ? (snapshot.message ?? NSLocalizedString("Nada tocando", comment: "Nothing playing")) : snapshot.track)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: 12) {
                        control("backward.fill", .previous)
                        control(snapshot.isPlaying ? "pause.fill" : "play.fill", .playPause)
                        control("forward.fill", .next)
                    }
                }
            }
            .frame(width: 128, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .frame(height: DockMetrics.itemHeight)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))
        .help(snapshot.track.isEmpty
              ? "Controle de \(provider.title). O macOS pode pedir acesso à Automação."
              : "\(snapshot.track) — \(snapshot.artist)")
        .onAppear { if music.connected.contains(provider) { music.refresh(provider) } }
        .onReceive(Timer.publish(every: 8, on: .main, in: .common).autoconnect()) { _ in
            if music.connected.contains(provider) { music.refresh(provider) }
        }
    }

    private func control(_ symbol: String, _ command: MusicCommand) -> some View {
        Button { music.command(command, for: provider) } label: {
            Image(systemName: symbol).frame(width: 20, height: 18)
        }
        .buttonStyle(.plain)
        .disabled(isPreview)
    }

    private func openProvider() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: provider.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
