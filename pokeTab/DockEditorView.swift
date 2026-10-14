import AppKit
import SwiftUI

struct DockEditorView: View {
    @ObservedObject private var dock = CustomDockController.shared
    @ObservedObject private var dockAutoHide = DockAutoHideController.shared
    @ObservedObject private var loginItem = LoginItemController.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                HStack(spacing: 10) {
                    Circle().fill(GameBoyPalette.action.gradient)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 3))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CONFIGURAR DOCK")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .tracking(1)
                        Text("TEMAS • APPS • WIDGETS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(GameBoyPalette.mid)
                    }
                    Spacer()
                    Toggle("Barra ativa", isOn: $dock.isEnabled)
                        .toggleStyle(.switch)
                        .tint(GameBoyPalette.action)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                }

                GameBoyScreen {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("Prévia", symbol: "eye")
                        HStack {
                            Spacer(minLength: 0)
                            CustomDockView(isPreview: true)
                                .frame(height: DockMetrics.panelHeight + 4)
                            Spacer(minLength: 0)
                        }
                    }
                }

                GameBoyScreen {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("Temas", symbol: "paintpalette")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3), spacing: 9) {
                            ForEach(DockTheme.allCases) { theme in
                                Button { dock.theme = theme } label: {
                                    HStack(spacing: 9) {
                                        Image("pokemon-\(theme.pokemonID)")
                                            .resizable()
                                            .interpolation(.none)
                                            .scaledToFit()
                                            .frame(width: 46, height: 46)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(theme.localizedName.uppercased())
                                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                            Text(theme.subtitle)
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .opacity(0.9)
                                        }
                                        Spacer(minLength: 0)
                                        if dock.theme == theme {
                                            Image(systemName: "checkmark.circle.fill")
                                        }
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, minHeight: 68)
                                    .foregroundStyle(.white)
                                    .background(LinearGradient(colors: theme.colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 5))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 5)
                                            .strokeBorder(dock.theme == theme ? GameBoyPalette.action : GameBoyPalette.dark, lineWidth: dock.theme == theme ? 4 : 2)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(dock.theme == theme ? .isSelected : [])
                            }
                        }
                    }
                }

                GameBoyScreen {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("Aparência e comportamento", symbol: "slider.horizontal.3")
                        Toggle("Animar o tema", isOn: $dock.animationsEnabled)
                        Toggle("Mostrar apps em execução", isOn: $dock.showRunningApps)
                        Toggle("Abrir ao iniciar sessão", isOn: Binding(
                            get: { loginItem.isEnabled },
                            set: { loginItem.setEnabled($0) }
                        ))
                        if loginItem.requiresApproval {
                            Button("Autorizar nos Ajustes do Sistema") { loginItem.openSystemSettings() }
                        }
                        if let error = loginItem.errorMessage {
                            Text(error).font(.caption).foregroundStyle(GameBoyPalette.action)
                        }
                        Text("O ajuste Reduzir Movimento do macOS também pausa os efeitos.")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(GameBoyPalette.mid)
                    }
                    .tint(GameBoyPalette.action)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                }

                GameBoyScreen {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            sectionTitle("Itens da barra", symbol: "square.grid.3x1.below.line.grid.1x2")
                            Spacer()
                            Menu("Adicionar app", systemImage: "plus.app") {
                                Button("Finder") { dock.addFinder() }
                                    .disabled(dock.hasFinder)
                                Button("Lixeira") { dock.addTrash() }
                                    .disabled(dock.items.contains { $0.kind == .trash })
                                Divider()
                                Button("Escolher app…") { dock.chooseApp() }
                            }
                            Menu("Adicionar widget", systemImage: "plus.square") {
                                Section("Pokémon e relógio") { widgetOptions([.clock, .pokedex, .encounter]) }
                                Section("Música") { widgetOptions([.spotify, .appleMusic]) }
                                Section("Finanças") { widgetOptions([.dollar, .budget]) }
                                Section("Produtividade") { widgetOptions([.focus, .tasks, .notes]) }
                            }
                        }
                        if dock.items.isEmpty {
                            ContentUnavailableView("Barra vazia", systemImage: "square.dashed", description: Text("Adicione apps ou widgets para começar."))
                                .frame(maxWidth: .infinity)
                        } else {
                            ForEach(dock.items) { item in
                                itemRow(item)
                            }
                        }
                        Text("Use as setas para definir a ordem. O ícone da Pokédex e o Pokémon do encontro ficam sempre nas pontas da barra.")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(GameBoyPalette.mid)
                        Text("Spotify e Música pedem acesso à Automação somente quando você toca em Conectar no widget.")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(GameBoyPalette.mid)
                    }
                }

                Text("Ao ativar a barra Pokémon, o pokeTab liga a ocultação automática da Dock do macOS. A Dock original ainda aparece ao levar o cursor à borda da tela.")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(GameBoyPalette.mid)
                if let errorMessage = dockAutoHide.errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(GameBoyPalette.action)
                    Button("Tentar novamente") { dockAutoHide.sync(enabled: dock.isEnabled) }
                        .buttonStyle(GameBoyActionStyle(primary: true))
                }
            }
            .padding(20)
        }
        .frame(minWidth: 760, minHeight: 620)
        .background(GameBoyPalette.shell)
        .foregroundStyle(GameBoyPalette.dark)
        .onAppear { loginItem.refresh() }
    }

    private func sectionTitle(_ title: String, symbol: String) -> some View {
        GameBoySectionTitle(title: title, symbol: symbol)
    }

    private func widgetOptions(_ kinds: [DockWidgetKind]) -> some View {
        ForEach(kinds) { kind in
            Button(kind.title, systemImage: kind.symbol) { dock.addWidget(kind) }
                .disabled(dock.items.contains { $0.widgetKind == kind })
        }
    }

    private func itemRow(_ item: DockItem) -> some View {
        let index = dock.items.firstIndex(where: { $0.id == item.id }) ?? 0
        return HStack(spacing: 12) {
            Group {
                if let kind = item.widgetKind {
                    Image(systemName: kind.symbol)
                        .font(.title3)
                        .foregroundStyle(GameBoyPalette.dark)
                } else {
                    Image(nsImage: item.icon)
                        .resizable()
                        .frame(width: 28, height: 28)
                }
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.system(size: 12, weight: .black, design: .monospaced))
                Text(NSLocalizedString(item.kind == .app ? "Aplicativo" : item.kind == .trash ? "Atalho do Finder" : "Widget", comment: "Dock item type"))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(GameBoyPalette.mid)
            }
            Spacer()
            if let kind = item.widgetKind, [.budget, .focus, .tasks, .notes].contains(kind) {
                Button("Abrir painel", systemImage: "arrow.up.right.square") {
                    openWindow(id: kind == .budget ? "finance" : "productivity")
                }
                .labelStyle(.iconOnly)
                .help("Abrir \(kind.title)")
            }
            Button("Mover para a esquerda", systemImage: "arrow.left") { dock.move(item, by: -1) }
                .labelStyle(.iconOnly)
                .disabled(index == 0)
            Button("Mover para a direita", systemImage: "arrow.right") { dock.move(item, by: 1) }
                .labelStyle(.iconOnly)
                .disabled(index == dock.items.count - 1)
            Button("Remover", systemImage: "trash") { dock.remove(item) }
                .labelStyle(.iconOnly)
                .help("Remover \(item.name)")
        }
        .padding(10)
        .background(GameBoyPalette.light, in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(GameBoyPalette.dark.opacity(0.65), lineWidth: 2))
    }
}
