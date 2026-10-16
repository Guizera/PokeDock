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
    var album = ""
    var artworkURL: URL?
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
        let trackDetails = switch provider {
        case .spotify:
            """
            set albumName to album of current track as text
            set coverURL to artwork url of current track as text
            return playbackState & linefeed & songName & linefeed & artistName & linefeed & albumName & linefeed & coverURL
            """
        case .appleMusic:
            """
            set albumName to album of current track as text
            return playbackState & linefeed & songName & linefeed & artistName & linefeed & albumName & linefeed
            """
        }
        let source = """
        tell application id "\(provider.bundleID)"
            set playbackState to player state as text
            if playbackState is "stopped" then return "stopped"
            try
                set songName to name of current track as text
                set artistName to artist of current track as text
                \(trackDetails)
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
                album: parts.count > 3 ? parts[3] : "",
                artworkURL: parts.count > 4 ? URL(string: parts[4]) : nil,
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
        HStack(spacing: 9) {
            MusicArtworkView(provider: provider, snapshot: snapshot)

            VStack(alignment: .leading, spacing: 3) {
                if !isRunning {
                    widgetTitle
                    actionButton("Abrir app") { openProvider() }
                } else if !music.connected.contains(provider) {
                    widgetTitle
                    actionButton("Conectar") { music.connect(provider) }
                } else if snapshot.track.isEmpty {
                    widgetTitle
                    Text(snapshot.message ?? NSLocalizedString("Nada tocando", comment: "Nothing playing"))
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                        .opacity(0.78)
                } else {
                    Text(snapshot.track)
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(snapshot.artist)
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                            .opacity(0.72)
                        Spacer(minLength: 2)
                        control("backward.fill", .previous)
                        control(snapshot.isPlaying ? "pause.fill" : "play.fill", .playPause, prominent: true)
                        control("forward.fill", .next)
                    }
                }
            }
            .frame(width: 158, alignment: .leading)
        }
        .padding(.horizontal, 8)
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

    private var widgetTitle: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(provider == .spotify ? Color(red: 0.12, green: 0.84, blue: 0.38) : Color.pink)
                .frame(width: 6, height: 6)
            Text(provider.title)
                .font(.system(size: 10, weight: .bold))
                .opacity(0.82)
        }
    }

    private func actionButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 8)
                .frame(height: 20)
                .background(.white.opacity(0.16), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isPreview)
    }

    private func control(_ symbol: String, _ command: MusicCommand, prominent: Bool = false) -> some View {
        Button { music.command(command, for: provider) } label: {
            Image(systemName: symbol)
                .font(.system(size: prominent ? 9 : 8, weight: .bold))
                .frame(width: prominent ? 20 : 17, height: 17)
                .background(.white.opacity(prominent ? 0.24 : 0.10), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(isPreview)
    }

    private func openProvider() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: provider.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}

private struct MusicArtworkView: View {
    let provider: MusicProvider
    let snapshot: MusicSnapshot

    var body: some View {
        Group {
            if let url = snapshot.artworkURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.28), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: provider == .spotify
                    ? [Color(red: 0.08, green: 0.72, blue: 0.31), Color(red: 0.03, green: 0.22, blue: 0.12)]
                    : [Color.pink, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: provider.symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}
