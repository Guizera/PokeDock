import AppKit
import Combine
import SwiftUI

enum DockMetrics {
    static let itemHeight: CGFloat = 50
    static let iconSize: CGFloat = 42
    static let horizontalPadding: CGFloat = 14
    static let itemSpacing: CGFloat = 8
    static let innerVerticalPadding: CGFloat = 5
    static let outerTopPadding: CGFloat = 6
    static let outerBottomPadding: CGFloat = 4
    static let panelHeight = itemHeight + innerVerticalPadding * 2 + outerTopPadding + outerBottomPadding
    // Fixed controls, four gaps and both layers of horizontal padding.
    static let fixedWidth = itemHeight + 9 + 54 + 36 + itemSpacing * 4 + horizontalPadding * 4
}

private struct DockContentWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

enum DockTheme: String, CaseIterable, Identifiable {
    case meadow = "Pradaria"
    case electric = "Elétrico"
    case night = "Noturno"
    case ocean = "Oceano"
    case volcanic = "Vulcânico"
    case psychic = "Psíquico"

    var id: String { rawValue }
    var localizedName: String { NSLocalizedString(rawValue, comment: "Dock theme") }

    var subtitle: String {
        switch self {
        case .meadow: NSLocalizedString("Folhas ao vento", comment: "Meadow theme subtitle")
        case .electric: NSLocalizedString("Raios e faíscas", comment: "Electric theme subtitle")
        case .night: NSLocalizedString("Névoa e estrelas", comment: "Night theme subtitle")
        case .ocean: NSLocalizedString("Ondas suaves", comment: "Ocean theme subtitle")
        case .volcanic: NSLocalizedString("Brasas flutuantes", comment: "Volcanic theme subtitle")
        case .psychic: NSLocalizedString("Orbes luminosas", comment: "Psychic theme subtitle")
        }
    }

    var colors: [Color] {
        switch self {
        case .meadow: [Color(red: 0.10, green: 0.35, blue: 0.25), Color(red: 0.38, green: 0.68, blue: 0.34)]
        case .electric: [Color(red: 0.43, green: 0.22, blue: 0.07), Color(red: 0.95, green: 0.66, blue: 0.11)]
        case .night: [Color(red: 0.07, green: 0.08, blue: 0.20), Color(red: 0.30, green: 0.19, blue: 0.43)]
        case .ocean: [Color(red: 0.04, green: 0.27, blue: 0.43), Color(red: 0.10, green: 0.63, blue: 0.74)]
        case .volcanic: [Color(red: 0.29, green: 0.08, blue: 0.10), Color(red: 0.78, green: 0.27, blue: 0.10)]
        case .psychic: [Color(red: 0.25, green: 0.12, blue: 0.42), Color(red: 0.60, green: 0.33, blue: 0.70)]
        }
    }

    var pokemonID: Int {
        switch self {
        case .meadow: 1
        case .electric: 25
        case .night: 94
        case .ocean: 7
        case .volcanic: 4
        case .psychic: 151
        }
    }
}

enum DockWidgetKind: String, CaseIterable, Codable, Identifiable {
    case clock
    case pokedex
    case encounter
    case spotify
    case appleMusic
    case dollar
    case budget
    case focus
    case tasks
    case notes
    case arcade

    var id: String { rawValue }
    var title: String {
        switch self {
        case .clock: NSLocalizedString("Relógio", comment: "Clock widget")
        case .pokedex: NSLocalizedString("Pokédex", comment: "Pokédex widget")
        case .encounter: NSLocalizedString("Próximo encontro", comment: "Next encounter widget")
        case .spotify: "Spotify"
        case .appleMusic: NSLocalizedString("Música", comment: "Apple Music widget")
        case .dollar: NSLocalizedString("Dólar USD/BRL", comment: "Dollar widget")
        case .budget: NSLocalizedString("Finanças", comment: "Finance widget")
        case .focus: NSLocalizedString("Foco", comment: "Focus widget")
        case .tasks: NSLocalizedString("Tarefas", comment: "Tasks widget")
        case .notes: NSLocalizedString("Notas rápidas", comment: "Quick notes widget")
        case .arcade: NSLocalizedString("Arcade retrô", comment: "Retro arcade widget")
        }
    }
    var symbol: String {
        switch self {
        case .clock: "clock"
        case .pokedex: "square.grid.2x2.fill"
        case .encounter: "sparkles"
        case .spotify: "music.note"
        case .appleMusic: "music.note.list"
        case .dollar: "dollarsign.circle"
        case .budget: "chart.pie.fill"
        case .focus: "timer"
        case .tasks: "checklist"
        case .notes: "note.text"
        case .arcade: "gamecontroller.fill"
        }
    }
}

struct DockItem: Codable, Identifiable, Hashable {
    enum Kind: String, Codable { case app, widget, trash }
    var id: UUID = UUID()
    let kind: Kind
    let value: String

    static func app(_ path: String) -> DockItem { DockItem(kind: .app, value: path) }
    static func widget(_ kind: DockWidgetKind) -> DockItem { DockItem(kind: .widget, value: kind.rawValue) }
    static func trash() -> DockItem { DockItem(kind: .trash, value: "system-trash") }
    var widgetKind: DockWidgetKind? { kind == .widget ? DockWidgetKind(rawValue: value) : nil }
    var name: String {
        if kind == .trash { return NSLocalizedString("Lixeira", comment: "Trash item") }
        if let widgetKind { return widgetKind.title }
        return URL(fileURLWithPath: value).deletingPathExtension().lastPathComponent
    }
    var icon: NSImage {
        if kind == .trash {
            return NSImage(named: NSImage.trashEmptyName)
                ?? NSImage(systemSymbolName: "trash", accessibilityDescription: NSLocalizedString("Lixeira", comment: "Trash icon"))
                ?? NSImage()
        }
        return NSWorkspace.shared.icon(forFile: value)
    }
}

struct DockRunningApp: Identifiable {
    let application: NSRunningApplication
    var id: pid_t { application.processIdentifier }
    var name: String { application.localizedName ?? NSLocalizedString("Aplicativo", comment: "App fallback name") }
    var icon: NSImage? { application.icon }
}

@MainActor
final class CustomDockController: ObservableObject {
    static let shared = CustomDockController()

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.enabled)
            AppDelegate.shared?.syncCustomDock()
        }
    }
    @Published var theme: DockTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme) }
    }
    @Published var animationsEnabled: Bool {
        didSet { UserDefaults.standard.set(animationsEnabled, forKey: Keys.animations) }
    }
    @Published var showRunningApps: Bool {
        didSet { UserDefaults.standard.set(showRunningApps, forKey: Keys.runningApps) }
    }
    @Published private(set) var items: [DockItem] = []
    @Published private(set) var runningApps: [DockRunningApp] = []
    @Published private var hiddenRunningAppPIDs: Set<pid_t> = []

    private enum Keys {
        static let enabled = "customDockEnabled.v1"
        static let theme = "customDockTheme.v1"
        static let favorites = "customDockFavorites.v1"
        static let items = "customDockItems.v2"
        static let animations = "customDockAnimations.v1"
        static let runningApps = "customDockRunningApps.v1"
        static let systemItemsAdded = "customDockSystemItemsAdded.v1"
    }

    private init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
        theme = DockTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .meadow
        animationsEnabled = defaults.object(forKey: Keys.animations) as? Bool ?? true
        showRunningApps = defaults.object(forKey: Keys.runningApps) as? Bool ?? true
        if let data = defaults.data(forKey: Keys.items), let saved = try? JSONDecoder().decode([DockItem].self, from: data) {
            items = saved.filter { item in
                switch item.kind {
                case .app: FileManager.default.fileExists(atPath: item.value)
                case .widget: item.widgetKind != nil
                case .trash: true
                }
            }
        } else {
            let oldFavorites = defaults.stringArray(forKey: Keys.favorites) ?? []
            items = oldFavorites.filter { FileManager.default.fileExists(atPath: $0) }.map(DockItem.app)
            items.append(DockItem.widget(.clock))
            items.append(DockItem.widget(.pokedex))
        }
        if !defaults.bool(forKey: Keys.systemItemsAdded) {
            addFinder()
            addTrash()
            defaults.set(true, forKey: Keys.systemItemsAdded)
        }
        refreshRunningApps()
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(workspaceChanged), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(workspaceChanged), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
    }

    @objc private func workspaceChanged(_ notification: Notification) { refreshRunningApps() }

    func refreshRunningApps() {
        runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isTerminated && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
            .map(DockRunningApp.init(application:))
        hiddenRunningAppPIDs.formIntersection(Set(runningApps.map(\.id)))
    }

    var unpinnedRunningApps: [DockRunningApp] {
        guard showRunningApps else { return [] }
        let paths = Set(items.filter { $0.kind == .app }.map(\.value))
        return runningApps.filter {
            guard !hiddenRunningAppPIDs.contains($0.id) else { return false }
            guard let path = $0.application.bundleURL?.path else { return true }
            return !paths.contains(path)
        }
    }

    func isRunning(_ item: DockItem) -> Bool {
        runningApplication(for: item) != nil
    }

    func chooseApp() {
        let panel = NSOpenPanel()
        panel.title = NSLocalizedString("Adicionar app à barra Pokémon", comment: "Open panel title")
        panel.prompt = NSLocalizedString("Adicionar", comment: "Open panel action")
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false
        guard panel.runModal() == .OK, let url = panel.url, url.pathExtension.lowercased() == "app" else { return }
        guard !items.contains(where: { $0.kind == .app && $0.value == url.path }) else { return }
        insertBeforeTrash(.app(url.path))
        persistItems()
    }

    var hasFinder: Bool {
        items.contains { item in
            guard item.kind == .app else { return false }
            return Bundle(url: URL(fileURLWithPath: item.value))?.bundleIdentifier == "com.apple.finder"
                || URL(fileURLWithPath: item.value).lastPathComponent == "Finder.app"
        }
    }

    func addFinder() {
        guard !hasFinder else { return }
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.finder")
            ?? URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        items.insert(.app(url.path), at: 0)
        persistItems()
    }

    func addTrash() {
        guard !items.contains(where: { $0.kind == .trash }) else { return }
        items.append(.trash())
        persistItems()
    }

    func addWidget(_ kind: DockWidgetKind) {
        guard !items.contains(where: { $0.widgetKind == kind }) else { return }
        insertBeforeTrash(.widget(kind))
        persistItems()
    }

    private func insertBeforeTrash(_ item: DockItem) {
        items.insert(item, at: items.firstIndex(where: { $0.kind == .trash }) ?? items.endIndex)
    }

    func remove(_ item: DockItem) {
        if let running = runningApplication(for: item) {
            hiddenRunningAppPIDs.insert(running.processIdentifier)
        }
        items.removeAll { $0.id == item.id }
        persistItems()
    }

    func hide(_ app: DockRunningApp) {
        hiddenRunningAppPIDs.insert(app.id)
    }

    func canQuit(_ item: DockItem) -> Bool {
        guard let app = runningApplication(for: item) else { return false }
        return canQuit(app)
    }

    func canQuit(_ app: DockRunningApp) -> Bool {
        canQuit(app.application)
    }

    func quit(_ item: DockItem) {
        guard let app = runningApplication(for: item), canQuit(app) else { return }
        _ = app.terminate()
    }

    func quit(_ app: DockRunningApp) {
        guard canQuit(app) else { return }
        _ = app.application.terminate()
    }

    private func canQuit(_ app: NSRunningApplication) -> Bool {
        !app.isTerminated && app.bundleIdentifier != "com.apple.finder"
    }

    func move(_ item: DockItem, by offset: Int) {
        guard let index = items.firstIndex(where: { $0.id == item.id }),
              items.indices.contains(index + offset) else { return }
        items.swapAt(index, index + offset)
        persistItems()
    }

    func openApp(_ item: DockItem) {
        guard item.kind == .app else { return }
        let url = URL(fileURLWithPath: item.value)
        if let running = runningApplication(for: item) {
            bringForward(running, fallbackURL: url)
        } else {
            launch(url)
        }
    }

    func openTrash() {
        Task.detached {
            var error: NSDictionary?
            let script = NSAppleScript(source: "tell application id \"com.apple.finder\" to open trash")
            _ = script?.executeAndReturnError(&error)
            if error != nil || script == nil {
                let localTrash = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash", isDirectory: true)
                await MainActor.run { _ = NSWorkspace.shared.open(localTrash) }
            }
        }
    }

    func activate(_ app: DockRunningApp) {
        bringForward(app.application, fallbackURL: app.application.bundleURL)
    }

    private func runningApplication(for item: DockItem) -> NSRunningApplication? {
        guard item.kind == .app else { return nil }
        let path = URL(fileURLWithPath: item.value).standardizedFileURL.path
        return NSWorkspace.shared.runningApplications.first {
            !$0.isTerminated && $0.bundleURL?.standardizedFileURL.path == path
        }
    }

    private func bringForward(_ app: NSRunningApplication, fallbackURL: URL?) {
        if app.isHidden { _ = app.unhide() }
        if !app.activate(options: [.activateAllWindows]), let fallbackURL {
            launch(fallbackURL)
        }
    }

    private func launch(_ url: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    private func persistItems() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: Keys.items)
    }
}

struct CustomDockView: View {
    var isPreview = false
    @State private var previewContentWidth: CGFloat = 0
    @ObservedObject private var dock = CustomDockController.shared
    @ObservedObject private var game = GameController.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: DockMetrics.itemSpacing) {
            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "pokedex")
            } label: {
                PokedexDockIcon()
                    .frame(width: 46, height: 46)
                    .frame(width: DockMetrics.itemHeight, height: DockMetrics.itemHeight)
            }
            .buttonStyle(DockIconButtonStyle())
            .help("Abrir Pokédex")
            .accessibilityLabel("Abrir Pokédex")
            .disabled(isPreview)

            dockDivider

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(dock.items) { item in
                        if let widget = item.widgetKind {
                            DockWidgetView(kind: widget, isPreview: isPreview)
                                .contextMenu {
                                    if !isPreview {
                                        Button(role: .destructive) { dock.remove(item) } label: {
                                            Label("Remover da barra", systemImage: "minus.circle")
                                        }
                                    }
                                }
                        } else {
                            Button {
                                if item.kind == .trash { dock.openTrash() }
                                else { dock.openApp(item) }
                            } label: {
                                Image(nsImage: item.icon)
                                    .resizable()
                                    .interpolation(.high)
                                    .frame(width: DockMetrics.iconSize, height: DockMetrics.iconSize)
                                    .frame(width: DockMetrics.itemHeight, height: DockMetrics.itemHeight)
                            }
                            .buttonStyle(DockIconButtonStyle())
                            .help(item.name)
                            .accessibilityLabel(item.name)
                            .overlay(alignment: .bottom) {
                                if dock.isRunning(item) {
                                    Circle().fill(.white).frame(width: 5, height: 5).offset(y: 5)
                                }
                            }
                            .disabled(isPreview)
                            .contextMenu {
                                if !isPreview {
                                    if dock.canQuit(item) {
                                        Button { dock.quit(item) } label: {
                                            Label("Encerrar app", systemImage: "xmark.circle")
                                        }
                                    }
                                    Button(role: .destructive) { dock.remove(item) } label: {
                                        Label("Remover da barra", systemImage: "minus.circle")
                                    }
                                }
                            }
                        }
                    }
                    if !dock.items.isEmpty && !dock.unpinnedRunningApps.isEmpty { dockDivider }
                    ForEach(dock.unpinnedRunningApps) { app in
                        Button { dock.activate(app) } label: {
                            Group {
                                if let icon = app.icon {
                                    Image(nsImage: icon).resizable().interpolation(.high)
                                } else {
                                    Image(systemName: "app.fill").resizable()
                                }
                            }
                            .frame(width: DockMetrics.iconSize, height: DockMetrics.iconSize)
                            .frame(width: DockMetrics.itemHeight, height: DockMetrics.itemHeight)
                        }
                        .buttonStyle(DockIconButtonStyle())
                        .help(app.name)
                        .disabled(isPreview)
                        .contextMenu {
                            if !isPreview {
                                if dock.canQuit(app) {
                                    Button { dock.quit(app) } label: {
                                        Label("Encerrar app", systemImage: "xmark.circle")
                                    }
                                }
                                Button(role: .destructive) { dock.hide(app) } label: {
                                    Label("Remover da barra", systemImage: "minus.circle")
                                }
                            }
                        }
                    }
                }
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: DockContentWidthPreferenceKey.self, value: geometry.size.width)
                    }
                }
            }

            if let species = game.currentEncounter {
                Button { AppDelegate.shared?.showEncounter() } label: {
                    Image(species.spriteName)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 46, height: 46)
                        .frame(width: 54, height: DockMetrics.itemHeight)
                }
                .buttonStyle(DockIconButtonStyle())
                .help("Capturar \(species.name)")
                .accessibilityLabel("Encontro com \(species.name)")
                .disabled(isPreview)
            } else {
                Image("pokemon-\(dock.theme.pokemonID)")
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 46, height: 46)
                    .frame(width: 54, height: DockMetrics.itemHeight)
                    .opacity(0.86)
                .accessibilityLabel("Decoração \(dock.theme.localizedName)")
            }

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "dock-editor")
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 36, height: DockMetrics.itemHeight)
            }
            .buttonStyle(DockIconButtonStyle())
            .help("Personalizar barra")
            .disabled(isPreview)
        }
        .padding(.horizontal, DockMetrics.horizontalPadding)
        .padding(.vertical, DockMetrics.innerVerticalPadding)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: dock.theme.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay { DockThemeEffect(theme: dock.theme, isEnabled: dock.animationsEnabled) }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.white.opacity(0.4), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, DockMetrics.horizontalPadding)
        .padding(.top, DockMetrics.outerTopPadding)
        .padding(.bottom, DockMetrics.outerBottomPadding)
        .frame(maxWidth: isPreview ? DockMetrics.fixedWidth + previewContentWidth : .infinity)
        .onPreferenceChange(DockContentWidthPreferenceKey.self) { width in
            guard width.isFinite else { return }
            if isPreview { previewContentWidth = width }
            else { AppDelegate.shared?.updateCustomDockContentWidth(width) }
        }
    }

    private var dockDivider: some View {
        Rectangle().fill(.white.opacity(0.40)).frame(width: 1, height: 38).padding(.horizontal, 4)
    }
}

private struct PokedexDockIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .fill(Color(red: 0.30, green: 0.06, blue: 0.09))
                .frame(width: 42, height: 46)
                .position(x: 23, y: 23)
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [Color(red: 1.00, green: 0.35, blue: 0.30), Color(red: 0.76, green: 0.08, blue: 0.13)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 38, height: 42)
                .position(x: 22, y: 22)
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                .frame(width: 37, height: 41)
                .position(x: 22, y: 22)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.45, green: 0.05, blue: 0.09))
                .frame(width: 4, height: 29)
                .position(x: 39, y: 27)

            Circle().fill(Color(red: 0.28, green: 0.16, blue: 0.19))
                .frame(width: 16, height: 16).position(x: 13, y: 11)
            Circle().fill(.white).frame(width: 13, height: 13).position(x: 13, y: 11)
            Circle().fill(LinearGradient(
                colors: [Color(red: 0.66, green: 0.99, blue: 1), Color(red: 0.08, green: 0.54, blue: 0.90)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: 10, height: 10).position(x: 13, y: 11)
            Circle().fill(.white.opacity(0.95)).frame(width: 3, height: 3).position(x: 11, y: 9)
            Circle().fill(.yellow).frame(width: 3, height: 3).position(x: 27, y: 9)
            Circle().fill(.green).frame(width: 3, height: 3).position(x: 33, y: 9)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.23, green: 0.23, blue: 0.29))
                .frame(width: 30, height: 21).position(x: 22, y: 27)
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(
                    colors: [Color(red: 0.75, green: 0.99, blue: 0.91), Color(red: 0.29, green: 0.73, blue: 0.77)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 24, height: 15).position(x: 22, y: 27)
            PokeballMark().frame(width: 12, height: 12).position(x: 22, y: 27)

            RoundedRectangle(cornerRadius: 1)
                .fill(Color(red: 0.32, green: 0.06, blue: 0.10))
                .frame(width: 10, height: 3).position(x: 14, y: 40)
            Circle().fill(Color(red: 0.22, green: 0.20, blue: 0.26))
                .frame(width: 5, height: 5).position(x: 31, y: 40)
        }
        .frame(width: 46, height: 46)
        .accessibilityHidden(true)
    }
}

struct DockWidgetView: View {
    let kind: DockWidgetKind
    let isPreview: Bool
    @ObservedObject private var game = GameController.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            switch kind {
            case .spotify: MusicDockWidgetView(provider: .spotify, isPreview: isPreview)
            case .appleMusic: MusicDockWidgetView(provider: .appleMusic, isPreview: isPreview)
            case .dollar: DollarDockWidgetView(isPreview: isPreview)
            case .budget: BudgetDockWidgetView(isPreview: isPreview)
            case .focus: FocusDockWidgetView(isPreview: isPreview)
            case .tasks: TasksDockWidgetView(isPreview: isPreview)
            case .notes: NotesDockWidgetView(isPreview: isPreview)
            case .arcade: RetroArcadeDockWidgetView(isPreview: isPreview)
            case .clock, .pokedex, .encounter: basicWidget
            }
        }
    }

    private var basicWidget: some View {
        Button {
            guard !isPreview else { return }
            guard kind != .encounter else { return }
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "pokedex")
        } label: {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                HStack(spacing: 7) {
                    Image(systemName: kind.symbol).font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.title).font(.caption2.weight(.semibold)).opacity(0.8)
                        Text(detail(at: context.date))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                }
            }
            .frame(minWidth: 96, maxWidth: 130)
            .frame(height: DockMetrics.itemHeight)
            .padding(.horizontal, 7)
        }
        .buttonStyle(DockIconButtonStyle())
        .help(kind.title)
        .accessibilityLabel("\(kind.title): \(detail(at: Date()))")
    }

    private func detail(at date: Date) -> String {
        switch kind {
        case .clock:
            return date.formatted(date: .omitted, time: .shortened)
        case .pokedex:
            return "\(game.caughtCount)/151"
        case .encounter:
            if game.isPaused { return NSLocalizedString("Pausado", comment: "Encounter paused") }
            if game.currentEncounter != nil { return NSLocalizedString("Agora!", comment: "Encounter available now") }
            guard let next = game.nextEncounterAt else { return NSLocalizedString("Explorando", comment: "Waiting for encounter") }
            let minutes = max(0, Int(next.timeIntervalSince(date) / 60))
            return minutes < 60
                ? String(format: NSLocalizedString("em %d min", comment: "Minutes until encounter"), minutes)
                : String(format: NSLocalizedString("em %d h", comment: "Hours until encounter"), minutes / 60)
        default:
            return ""
        }
    }
}

private struct DockIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.white.opacity(configuration.isPressed ? 0.32 : 0.12), in: RoundedRectangle(cornerRadius: 15))
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
    }
}

struct CustomDockSettingsView: View {
    @ObservedObject private var dock = CustomDockController.shared
    @ObservedObject private var dockAutoHide = DockAutoHideController.shared
    @ObservedObject private var loginItem = LoginItemController.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dock Pokémon").font(.headline)
            Toggle("Mostrar barra personalizada", isOn: $dock.isEnabled)
            Toggle("Abrir ao iniciar sessão", isOn: Binding(
                get: { loginItem.isEnabled },
                set: { loginItem.setEnabled($0) }
            ))
            if loginItem.requiresApproval {
                Button("Autorizar nos Ajustes do Sistema") { loginItem.openSystemSettings() }
            }
            if let error = loginItem.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            Button("Personalizar temas, apps e widgets…") { openWindow(id: "dock-editor") }
            Text("Ao ativar a barra Pokémon, o pokeTab liga a ocultação automática da Dock do macOS. Ela volta ao levar o cursor à borda da tela.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let errorMessage = dockAutoHide.errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.orange)
                Button("Tentar novamente") { dockAutoHide.sync(enabled: dock.isEnabled) }
            }
        }
        .onAppear { loginItem.refresh() }
    }
}
