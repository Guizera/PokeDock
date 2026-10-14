import SwiftUI

private enum CollectionFilter: String, CaseIterable, Identifiable {
    case all = "Todos"
    case caught = "Capturados"
    case seen = "Vistos"
    case unknown = "Desconhecidos"
    var id: String { rawValue }
}

struct ContentView: View {
    @ObservedObject private var game = GameController.shared
    @State private var search = ""
    @State private var filter: CollectionFilter = .all
    @State private var showsSettings = false
    @Environment(\.openWindow) private var openWindow

    private var filteredSpecies: [PokemonSpecies] {
        PokemonCatalog.all.filter { species in
            let record = game.progress(for: species)
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = true
            case .caught: matchesFilter = record.caughtCount > 0
            case .seen: matchesFilter = record.seenCount > 0 && record.caughtCount == 0
            case .unknown: matchesFilter = record.seenCount == 0
            }
            return matchesFilter && (search.isEmpty || species.name.localizedCaseInsensitiveContains(search) || String(species.id).contains(search))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            header
            GameBoyScreen {
                VStack(alignment: .leading, spacing: 15) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("POKÉDEX / KANTO")
                                .font(.system(size: 20, weight: .black, design: .monospaced))
                                .tracking(1)
                            Text("151 ESPÉCIES PARA DESCOBRIR")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(GameBoyPalette.mid)
                        }
                        Spacer()
                        Text(NSLocalizedString(game.isPaused ? "PAUSADO" : game.currentEncounter == nil ? "EXPLORANDO" : "ENCONTRO DISPONÍVEL", comment: "Pokédex status"))
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(GameBoyPalette.light, in: RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(GameBoyPalette.dark, lineWidth: 2))
                    }
                    HStack(spacing: 9) {
                        stat("CAPTURADOS", "\(game.caughtCount)/151", "checkmark.circle.fill")
                        stat("VISTOS", "\(game.seenCount)/151", "eye.fill")
                        stat("REPETIDOS", "\(game.duplicateCount)", "arrow.triangle.2.circlepath")
                    }
                    HStack(spacing: 8) {
                        ForEach(CollectionFilter.allCases) { option in
                            Button(NSLocalizedString(option.rawValue, comment: "Pokédex filter").uppercased()) { filter = option }
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(filter == option ? Color.white : GameBoyPalette.dark)
                                .padding(.horizontal, 10)
                                .frame(height: 34)
                                .background(filter == option ? GameBoyPalette.action : GameBoyPalette.light, in: RoundedRectangle(cornerRadius: 5))
                                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(GameBoyPalette.dark, lineWidth: 2))
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(filter == option ? .isSelected : [])
                        }
                        Spacer(minLength: 4)
                        TextField("", text: $search, prompt: Text("BUSCAR NOME OU Nº").foregroundColor(GameBoyPalette.mid))
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(GameBoyPalette.dark)
                            .padding(.horizontal, 10)
                            .frame(width: 205, height: 34)
                            .background(GameBoyPalette.light, in: RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(GameBoyPalette.dark, lineWidth: 2))
                    }
                    Rectangle().fill(GameBoyPalette.dark).frame(height: 2)
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                            ForEach(filteredSpecies) { species in
                                SpeciesCard(species: species, progress: game.progress(for: species))
                            }
                        }
                        .padding(.trailing, 7)
                        .padding(.bottom, 10)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            HStack(spacing: 9) {
                Circle().fill(GameBoyPalette.action).frame(width: 11, height: 11)
                Text("POKÉTAB  •  SISTEMA DE ENCONTROS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1)
                Spacer()
                Text("A  •  SELECIONAR")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(GameBoyPalette.mid)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GameBoyPalette.shell)
        .foregroundStyle(GameBoyPalette.dark)
        .sheet(isPresented: $showsSettings) { SettingsView(game: game) }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Circle().fill(GameBoyPalette.action.gradient)
                .frame(width: 23, height: 23)
                .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 3))
            Text("POKÉTAB")
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .tracking(2)
            if game.currentEncounter != nil {
                Button("ABRIR ENCONTRO", systemImage: "sparkles") { AppDelegate.shared?.showEncounter() }
                    .buttonStyle(GameBoyActionStyle(primary: true))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(game.pokeballs)/\(GameController.maximumPokeballs) POKÉBOLAS")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                if let refill = game.pokeballsRefillAt {
                    Text("RECARGA \(refill, style: .relative)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                } else if let next = game.nextEncounterAt, !game.isPaused {
                    Text("PRÓXIMO \(next, style: .relative)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
            }
            Button("DOCK", systemImage: "paintpalette") { openWindow(id: "dock-editor") }
                .buttonStyle(GameBoyActionStyle())
            Button("AJUSTES", systemImage: "slider.horizontal.3") { showsSettings = true }
                .buttonStyle(GameBoyActionStyle())
        }
    }

    private func stat(_ title: String, _ value: String, _ symbol: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol).font(.system(size: 19, weight: .bold))
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(size: 17, weight: .black, design: .monospaced))
                Text(NSLocalizedString(title, comment: "Pokédex statistic")).font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(GameBoyPalette.light, in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(GameBoyPalette.dark, lineWidth: 2))
    }
}
private struct SpeciesCard: View {
    let species: PokemonSpecies
    let progress: PokemonProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(String(format: "#%03d", species.id))
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                Spacer()
                if progress.caughtCount > 1 {
                    Text("×\(progress.caughtCount)").font(.system(size: 11, weight: .black, design: .monospaced))
                }
            }
            Group {
                if progress.seenCount == 0 {
                    Image(systemName: "questionmark")
                        .font(.system(size: 38, weight: .black, design: .monospaced))
                        .foregroundStyle(GameBoyPalette.mid)
                } else {
                    Image(species.spriteName)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .opacity(progress.caughtCount > 0 ? 1 : 0.55)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .accessibilityHidden(true)
            Text(progress.seenCount == 0 ? "???" : species.name)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .lineLimit(1)
            Text(NSLocalizedString(progress.caughtCount > 0 ? "CAPTURADO" : progress.seenCount > 0 ? "VISTO" : "DESCONHECIDO", comment: "Species status"))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(GameBoyPalette.mid)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(progress.caughtCount > 0 ? GameBoyPalette.light : GameBoyPalette.screen.opacity(0.5), in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(GameBoyPalette.dark.opacity(0.6), lineWidth: 2))
        .foregroundStyle(GameBoyPalette.dark)
        .accessibilityElement(children: .combine)
    }
}

private struct SettingsView: View {
    @ObservedObject var game: GameController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Encontros").font(.title2.bold())
                Spacer()
                Button("Concluído") { dismiss() }
            }
            Picker("Frequência", selection: $game.frequency) {
                ForEach(EncounterFrequency.allCases) { frequency in
                    Text(frequency.localizedName).tag(frequency)
                }
            }
            Text(game.frequency.description)
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Pausar aparições", isOn: $game.isPaused)
            Text("Use a pausa quando estiver trabalhando, apresentando ou quiser silêncio. Os encontros voltam quando você reativar.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Divider()
            CustomDockSettingsView()
            #if DEBUG
            Divider()
            Button("Simular um encontro agora") {
                game.simulateEncounter()
                dismiss()
                AppDelegate.shared?.showEncounter()
            }
            .disabled(game.isPaused)
            #endif
        }
        .padding(24)
        .frame(width: 460)
    }
}
