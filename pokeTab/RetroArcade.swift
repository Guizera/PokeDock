import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers
import WebKit

private enum RetroGameKind: String, CaseIterable, Identifiable {
    case gameBoyColor
    case superNintendo
    case snake
    case memory

    var id: String { rawValue }
    var title: String {
        switch self {
        case .gameBoyColor: "GAME BOY COLOR"
        case .superNintendo: "SUPER NINTENDO"
        case .snake: NSLocalizedString("Cobrinha", comment: "Retro arcade snake game")
        case .memory: NSLocalizedString("Memória", comment: "Retro arcade memory game")
        }
    }

    var emulatedGame: EmulatedGame? {
        switch self {
        case .gameBoyColor: .gameBoyColor
        case .superNintendo: .superNintendo
        case .snake, .memory: nil
        }
    }
}

private enum EmulatedGame: String, Hashable {
    case gameBoyColor
    case superNintendo

    var title: String {
        switch self {
        case .gameBoyColor: "Game Boy Color"
        case .superNintendo: "Super Nintendo"
        }
    }

    var system: String {
        switch self {
        case .gameBoyColor, .superNintendo: "Nintendo"
        }
    }

    var core: String {
        switch self {
        case .gameBoyColor: "gb"
        case .superNintendo: "snes"
        }
    }

    var fileExtensions: [String] {
        switch self {
        case .gameBoyColor: ["gb", "gbc"]
        case .superNintendo: ["sfc", "smc"]
        }
    }

    var storageName: String {
        switch self {
        case .gameBoyColor: "game-boy-color"
        case .superNintendo: "super-nintendo"
        }
    }

    var symbol: String {
        switch self {
        case .gameBoyColor: "gamecontroller"
        case .superNintendo: "gamecontroller.fill"
        }
    }

    func matches(_ data: Data) -> Bool {
        switch self {
        case .gameBoyColor:
            guard data.count > 0x14D else { return false }
            var checksum: UInt8 = 0
            for index in 0x134...0x14C {
                checksum = checksum &- data[index] &- 1
            }
            return checksum == data[0x14D]
        case .superNintendo:
            guard data.count >= 32_768 else { return false }
            let headerOffsets = [0x7FC0, 0xFFC0, 0x81C0, 0x101C0]
            return headerOffsets.contains { offset in
                guard offset + 0x20 <= data.count else { return false }
                let title = data[offset..<(offset + 21)]
                let printableCharacters = title.filter { $0 == 0 || $0 == 0x20 || ($0 >= 0x21 && $0 <= 0x7E) }
                let mapMode = data[offset + 0x15] & 0x0F
                return printableCharacters.count == title.count && mapMode <= 5
            }
        }
    }
}

@MainActor
private final class RetroROMStore: ObservableObject {
    @Published private(set) var roms: [EmulatedGame: URL] = [:]
    @Published var errorMessage: String?

    init() {
        reload()
    }

    func romURL(for game: EmulatedGame) -> URL? {
        roms[game]
    }

    func importROM(for game: EmulatedGame) {
        let panel = NSOpenPanel()
        panel.title = String(format: NSLocalizedString("Importar ROM de %@", comment: "ROM import panel title"), game.title)
        panel.prompt = NSLocalizedString("Importar", comment: "Import ROM button")
        panel.message = String(
            format: NSLocalizedString("Selecione uma cópia própria nos formatos: %@.", comment: "ROM import panel help"),
            game.fileExtensions.map { ".\($0)" }.joined(separator: ", ")
        )
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = game.fileExtensions.compactMap { UTType(filenameExtension: $0) }

        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }

        do {
            let data = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
            guard game.matches(data) else { throw ROMImportError.incompatibleROM(game.title) }

            let directory = try Self.romDirectory()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let fileExtension = sourceURL.pathExtension.lowercased()
            let destination = directory
                .appendingPathComponent(game.storageName)
                .appendingPathExtension(fileExtension)
            try data.write(to: destination, options: .atomic)

            for oldExtension in game.fileExtensions where oldExtension != fileExtension {
                let oldURL = directory.appendingPathComponent(game.storageName).appendingPathExtension(oldExtension)
                try? FileManager.default.removeItem(at: oldURL)
            }

            roms[game] = destination
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reload() {
        guard let directory = try? Self.romDirectory() else { return }
        for game in [EmulatedGame.gameBoyColor, .superNintendo] {
            for fileExtension in game.fileExtensions {
                let candidate = directory.appendingPathComponent(game.storageName).appendingPathExtension(fileExtension)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    roms[game] = candidate
                    break
                }
            }
        }
    }

    private static func romDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent("PokeDock", isDirectory: true)
            .appendingPathComponent("ROMs", isDirectory: true)
    }
}

private enum ROMImportError: LocalizedError {
    case incompatibleROM(String)

    var errorDescription: String? {
        switch self {
        case .incompatibleROM(let title):
            String(
                format: NSLocalizedString("O arquivo não parece ser uma ROM compatível com %@.", comment: "Incompatible imported ROM error"),
                title
            )
        }
    }
}

struct RetroArcadeDockWidgetView: View {
    let isPreview: Bool
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button {
            guard !isPreview else { return }
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "retro-arcade")
        } label: {
            VStack(spacing: 1) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 22, weight: .bold))
                Text("ARCADE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(0.5)
            }
            .frame(width: 58, height: DockMetrics.itemHeight)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
        .help("Abrir arcade retrô")
        .accessibilityLabel("Abrir arcade retrô")
        .disabled(isPreview)
    }
}

struct RetroArcadeView: View {
    @StateObject private var romStore = RetroROMStore()
    @State private var selectedGame = RetroGameKind.gameBoyColor
    @State private var runningGame: EmulatedGame?

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("POKEDOCK")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(Color.white.opacity(0.72))
                    Text("RETRO ARCADE")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.white)
                }
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(Color.red.opacity(0.8)).frame(width: 9, height: 9)
                    Text("POWER")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.62))
                }
            }

            VStack(spacing: 12) {
                HStack(spacing: 4) {
                    ForEach(RetroGameKind.allCases) { game in
                        Button {
                            selectedGame = game
                        } label: {
                            Text(game.title.uppercased())
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                                .foregroundStyle(selectedGame == game ? Color.white : Color.white.opacity(0.72))
                                .frame(maxWidth: .infinity, minHeight: 30)
                                .background(
                                    selectedGame == game ? GameBoyPalette.action : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 7)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 9))
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Jogo")

                Group {
                    switch selectedGame {
                    case .gameBoyColor:
                        EmulatorSlotView(game: .gameBoyColor, store: romStore, runningGame: $runningGame)
                    case .superNintendo:
                        EmulatorSlotView(game: .superNintendo, store: romStore, runningGame: $runningGame)
                    case .snake: SnakeGameView()
                    case .memory: MemoryGameView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.10, green: 0.12, blue: 0.13))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.black.opacity(0.8), lineWidth: 4)
                    }
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 3)
            }

            HStack {
                Text(selectedGame.emulatedGame == nil
                     ? NSLocalizedString("Jogos originais • nenhuma ROM necessária", comment: "Original arcade games note")
                     : NSLocalizedString("Emulador disponível • ROM fornecida pelo usuário", comment: "User supplied ROM note"))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.58))
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.35))
                    .frame(width: 70, height: 8)
                    .overlay {
                        HStack(spacing: 4) {
                            ForEach(0..<7, id: \.self) { _ in
                                Capsule().fill(Color.black.opacity(0.45)).frame(width: 4, height: 2)
                            }
                        }
                    }
            }
        }
        .padding(20)
        .frame(width: 520, height: 580)
        .background {
            LinearGradient(
                colors: [Color(red: 0.29, green: 0.30, blue: 0.28), Color(red: 0.16, green: 0.17, blue: 0.17)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .onChange(of: selectedGame) { _, _ in runningGame = nil }
        .alert(
            NSLocalizedString("Não foi possível importar", comment: "ROM import error alert title"),
            isPresented: Binding(
                get: { romStore.errorMessage != nil },
                set: { if !$0 { romStore.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { romStore.errorMessage = nil }
        } message: {
            Text(romStore.errorMessage ?? "")
        }
    }
}

private struct EmulatorSlotView: View {
    let game: EmulatedGame
    @ObservedObject var store: RetroROMStore
    @Binding var runningGame: EmulatedGame?

    private var romURL: URL? { store.romURL(for: game) }
    private var isRunning: Bool { runningGame == game && romURL != nil }

    var body: some View {
        VStack(spacing: 10) {
            if isRunning, let romURL {
                EmulatorWebView(game: game, romURL: romURL)
                    .id(romURL)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(GameBoyPalette.dark, lineWidth: 3))
            } else {
                ZStack {
                    GameBoyPalette.screen
                    GameBoyScanlines().opacity(0.10)
                    VStack(spacing: 10) {
                        Image(systemName: game.symbol)
                            .font(.system(size: 42, weight: .black))
                            .foregroundStyle(GameBoyPalette.dark)
                        Text(game.title.uppercased())
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundStyle(GameBoyPalette.dark)
                        Text(game.system.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(GameBoyPalette.mid)

                        if let romURL {
                            Label(romURL.lastPathComponent, systemImage: "checkmark.circle.fill")
                                .lineLimit(1)
                                .foregroundStyle(GameBoyPalette.dark)
                        } else {
                            Text(instructions)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(GameBoyPalette.mid)
                        }
                    }
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .padding(18)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(GameBoyPalette.dark, lineWidth: 3))
            }

            HStack(spacing: 10) {
                Button(romURL == nil
                       ? NSLocalizedString("IMPORTAR ROM", comment: "Import ROM arcade button")
                       : NSLocalizedString("TROCAR ROM", comment: "Replace ROM arcade button")) {
                    runningGame = nil
                    store.importROM(for: game)
                }
                .buttonStyle(ArcadeActionButtonStyle())

                if romURL != nil {
                    Button(isRunning
                           ? NSLocalizedString("VOLTAR", comment: "Leave emulator button")
                           : NSLocalizedString("JOGAR", comment: "Play emulator button")) {
                        runningGame = isRunning ? nil : game
                    }
                    .buttonStyle(ArcadeActionButtonStyle())
                }

                Spacer()

                Text(NSLocalizedString("EmulatorJS • internet na primeira carga", comment: "Emulator internet requirement"))
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(GameBoyPalette.mid)
            }
        }
        .padding(12)
        .background(Color(red: 0.72, green: 0.72, blue: 0.65), in: RoundedRectangle(cornerRadius: 10))
    }

    private var instructions: String {
        let formats = game.fileExtensions.map { ".\($0)" }.joined(separator: " / ")
        return String(
            format: NSLocalizedString(
                "1. Faça um dump legal do seu cartucho.\n2. Clique em IMPORTAR ROM.\n3. Selecione o arquivo %@.\nA ROM fica somente neste Mac.",
                comment: "ROM import instructions"
            ),
            formats
        )
    }
}

private struct EmulatorWebView: NSViewRepresentable {
    let game: EmulatedGame
    let romURL: URL

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        loadGame(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    static func dismantleNSView(_ webView: WKWebView, coordinator: ()) {
        webView.stopLoading()
        webView.loadHTMLString("<html><body style='background:#111'></body></html>", baseURL: nil)
    }

    private func loadGame(in webView: WKWebView) {
        guard let romData = try? Data(contentsOf: romURL, options: .mappedIfSafe) else { return }
        let romDataURL = "data:application/octet-stream;base64,\(romData.base64EncodedString())"
        let dataPath = "https://cdn.emulatorjs.org/stable/data/"

        let html = """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            html, body, #game { width: 100%; height: 100%; margin: 0; overflow: hidden; background: #111; }
          </style>
        </head>
        <body>
          <div id="game"></div>
          <script>
            window.EJS_player = '#game';
            window.EJS_core = \(javascriptString(game.core));
            window.EJS_gameName = \(javascriptString("\(game.title).\(romURL.pathExtension.lowercased())"));
            window.EJS_gameUrl = \(javascriptString(romDataURL));
            window.EJS_pathtodata = \(javascriptString(dataPath));
            window.EJS_pathToData = \(javascriptString(dataPath));
            window.EJS_startOnLoaded = true;
            window.EJS_language = 'pt-BR';
            window.EJS_volume = 0.7;
            window.EJS_color = '#8e245c';
            window.EJS_backgroundColor = '#111111';
          </script>
          <script src="\(dataPath)loader.js"></script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: dataPath))
    }

    private func javascriptString(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value]),
              let array = String(data: data, encoding: .utf8) else { return "\"\"" }
        return String(array.dropFirst().dropLast())
    }
}

private struct SnakePoint: Hashable {
    let x: Int
    let y: Int
}

private enum SnakeDirection {
    case up, down, left, right
}

private struct SnakeGameView: View {
    private let columns = 18
    private let rows = 14
    private let timer = Timer.publish(every: 0.16, on: .main, in: .common).autoconnect()

    @State private var snake = [SnakePoint(x: 7, y: 7), SnakePoint(x: 6, y: 7), SnakePoint(x: 5, y: 7)]
    @State private var food = SnakePoint(x: 12, y: 7)
    @State private var direction = SnakeDirection.right
    @State private var queuedDirection = SnakeDirection.right
    @State private var isRunning = false
    @State private var isGameOver = false
    @State private var score = 0

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("PONTOS \(score)", systemImage: "star.fill")
                Spacer()
                Text(isGameOver ? "FIM DE JOGO" : isRunning ? "JOGANDO" : "PRONTO")
            }
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(GameBoyPalette.dark)

            ZStack {
                GameBoyPalette.screen
                SnakeBoard(snake: snake, food: food, columns: columns, rows: rows)
                GameBoyScanlines().opacity(0.12)
                if !isRunning {
                    Text(isGameOver ? "APERTE NOVO JOGO" : "APERTE JOGAR")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .padding(10)
                        .background(GameBoyPalette.light.opacity(0.92), in: RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(GameBoyPalette.dark, lineWidth: 2))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(GameBoyPalette.dark, lineWidth: 3))
            .focusable()
            .focusEffectDisabled()
            .onKeyPress(.upArrow) { turn(.up); return .handled }
            .onKeyPress(.downArrow) { turn(.down); return .handled }
            .onKeyPress(.leftArrow) { turn(.left); return .handled }
            .onKeyPress(.rightArrow) { turn(.right); return .handled }

            HStack(spacing: 18) {
                directionPad
                Spacer()
                Button(isGameOver ? "NOVO JOGO" : isRunning ? "PAUSAR" : "JOGAR") {
                    if isGameOver { reset() }
                    isRunning.toggle()
                }
                .buttonStyle(ArcadeActionButtonStyle())
            }
        }
        .padding(12)
        .background(Color(red: 0.72, green: 0.72, blue: 0.65), in: RoundedRectangle(cornerRadius: 10))
        .onReceive(timer) { _ in advance() }
    }

    private var directionPad: some View {
        VStack(spacing: 2) {
            directionButton("arrowtriangle.up.fill", .up)
            HStack(spacing: 2) {
                directionButton("arrowtriangle.left.fill", .left)
                Circle().fill(Color.black.opacity(0.55)).frame(width: 26, height: 26)
                directionButton("arrowtriangle.right.fill", .right)
            }
            directionButton("arrowtriangle.down.fill", .down)
        }
    }

    private func directionButton(_ symbol: String, _ newDirection: SnakeDirection) -> some View {
        Button { turn(newDirection) } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .black))
                .frame(width: 26, height: 26)
                .foregroundStyle(.white)
                .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    private func turn(_ newDirection: SnakeDirection) {
        let isOpposite = switch (direction, newDirection) {
        case (.up, .down), (.down, .up), (.left, .right), (.right, .left): true
        default: false
        }
        if !isOpposite { queuedDirection = newDirection }
    }

    private func advance() {
        guard isRunning, let head = snake.first else { return }
        direction = queuedDirection
        let next = switch direction {
        case .up: SnakePoint(x: head.x, y: head.y - 1)
        case .down: SnakePoint(x: head.x, y: head.y + 1)
        case .left: SnakePoint(x: head.x - 1, y: head.y)
        case .right: SnakePoint(x: head.x + 1, y: head.y)
        }

        guard next.x >= 0, next.x < columns, next.y >= 0, next.y < rows, !snake.contains(next) else {
            isRunning = false
            isGameOver = true
            return
        }

        snake.insert(next, at: 0)
        if next == food {
            score += 10
            placeFood()
        } else {
            snake.removeLast()
        }
    }

    private func placeFood() {
        let freeCells = (0..<rows).flatMap { y in
            (0..<columns).map { SnakePoint(x: $0, y: y) }
        }.filter { !snake.contains($0) }
        if let nextFood = freeCells.randomElement() { food = nextFood }
    }

    private func reset() {
        snake = [SnakePoint(x: 7, y: 7), SnakePoint(x: 6, y: 7), SnakePoint(x: 5, y: 7)]
        food = SnakePoint(x: 12, y: 7)
        direction = .right
        queuedDirection = .right
        score = 0
        isGameOver = false
        isRunning = false
    }
}

private struct SnakeBoard: View {
    let snake: [SnakePoint]
    let food: SnakePoint
    let columns: Int
    let rows: Int

    var body: some View {
        Canvas { context, size in
            let cellWidth = size.width / CGFloat(columns)
            let cellHeight = size.height / CGFloat(rows)
            for (index, point) in snake.enumerated() {
                let rect = CGRect(
                    x: CGFloat(point.x) * cellWidth + 1,
                    y: CGFloat(point.y) * cellHeight + 1,
                    width: cellWidth - 2,
                    height: cellHeight - 2
                )
                context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(index == 0 ? GameBoyPalette.dark : GameBoyPalette.mid))
            }
            let foodRect = CGRect(
                x: CGFloat(food.x) * cellWidth + 2,
                y: CGFloat(food.y) * cellHeight + 2,
                width: cellWidth - 4,
                height: cellHeight - 4
            )
            context.fill(Path(ellipseIn: foodRect), with: .color(GameBoyPalette.action))
        }
    }
}

private struct MemoryCard: Identifiable {
    let id = UUID()
    let symbol: String
}

private struct MemoryGameView: View {
    @State private var cards = Self.makeDeck()
    @State private var revealed: Set<UUID> = []
    @State private var matched: Set<UUID> = []
    @State private var moves = 0
    @State private var isLocked = false
    @State private var gameID = UUID()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("JOGADAS \(moves)", systemImage: "arrow.triangle.2.circlepath")
                Spacer()
                Text(matched.count == cards.count ? "VOCÊ VENCEU!" : "ENCONTRE OS PARES")
            }
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(GameBoyPalette.dark)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(cards) { card in
                    let isFaceUp = revealed.contains(card.id) || matched.contains(card.id)
                    Button { reveal(card) } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(isFaceUp ? GameBoyPalette.light : GameBoyPalette.dark)
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(GameBoyPalette.dark, lineWidth: 2)
                            if isFaceUp {
                                Image(systemName: card.symbol)
                                    .font(.system(size: 24, weight: .black))
                                    .foregroundStyle(GameBoyPalette.action)
                            } else {
                                Text("?")
                                    .font(.system(size: 24, weight: .black, design: .monospaced))
                                    .foregroundStyle(GameBoyPalette.screen)
                            }
                        }
                        .frame(height: 62)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLocked || isFaceUp)
                }
            }
            .padding(12)
            .background(GameBoyPalette.screen, in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(GameBoyPalette.dark, lineWidth: 3)
                    .overlay(GameBoyScanlines().opacity(0.08).clipShape(RoundedRectangle(cornerRadius: 6)))
            }

            HStack {
                Text("CLIQUE NAS CARTAS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(GameBoyPalette.mid)
                Spacer()
                Button("NOVO JOGO") { reset() }
                    .buttonStyle(ArcadeActionButtonStyle())
            }
        }
        .padding(12)
        .background(Color(red: 0.72, green: 0.72, blue: 0.65), in: RoundedRectangle(cornerRadius: 10))
    }

    private func reveal(_ card: MemoryCard) {
        guard !isLocked, !revealed.contains(card.id), !matched.contains(card.id) else { return }
        revealed.insert(card.id)
        guard revealed.count == 2 else { return }
        moves += 1
        let visible = cards.filter { revealed.contains($0.id) }
        if visible.count == 2, visible[0].symbol == visible[1].symbol {
            matched.formUnion(visible.map(\.id))
            revealed.removeAll()
        } else {
            isLocked = true
            let currentGameID = gameID
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(650))
                guard gameID == currentGameID else { return }
                revealed.removeAll()
                isLocked = false
            }
        }
    }

    private func reset() {
        gameID = UUID()
        cards = Self.makeDeck()
        revealed.removeAll()
        matched.removeAll()
        moves = 0
        isLocked = false
    }

    private static func makeDeck() -> [MemoryCard] {
        let symbols = ["bolt.fill", "flame.fill", "drop.fill", "leaf.fill", "moon.fill", "star.fill", "heart.fill", "sparkles"]
        return (symbols + symbols).map { MemoryCard(symbol: $0) }.shuffled()
    }
}

private struct ArcadeActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(GameBoyPalette.action, in: Capsule())
            .overlay(Capsule().strokeBorder(GameBoyPalette.dark, lineWidth: 2))
            .offset(y: configuration.isPressed ? 2 : 0)
    }
}
