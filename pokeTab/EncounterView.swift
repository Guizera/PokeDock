import SwiftUI

struct EncounterView: View {
    @ObservedObject var game: GameController
    let close: () -> Void

    @State private var battleMessage = NSLocalizedString("Um Pokémon selvagem apareceu!", comment: "Initial encounter message")
    @State private var isThrowing = false

    var body: some View {
        VStack(spacing: 14) {
            header
            battleScreen
            dialogue
            controls
            footer
        }
        .padding(.horizontal, 24)
        .padding(.top, 34)
        .padding(.bottom, 22)
        .frame(width: 520, height: 580)
        .background {
            GameBoyPalette.shell
                .overlay(alignment: .bottom) {
                    GameBoyPalette.shellShadow.frame(height: 7)
                }
        }
        .foregroundStyle(GameBoyPalette.dark)
        .onAppear {
            if game.encounterAttempts > 0 {
                battleMessage = NSLocalizedString("O Pokémon escapou. Tente novamente!", comment: "Encounter retry message")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                Circle()
                    .fill(GameBoyPalette.action.gradient)
                    .frame(width: 15, height: 15)
                    .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 2))
                Text("POKÉTAB")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .tracking(2)
            }
            Spacer()
            Text("ENCONTRO SELVAGEM")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(GameBoyPalette.mid)
        }
        .accessibilityElement(children: .combine)
    }

    private var battleScreen: some View {
        ZStack {
            GameBoyPalette.screen
            GameBoyScanlines()
                .opacity(0.15)
            if let species = game.currentEncounter {
                encounterScene(species)
            } else if let result = game.encounterResult {
                resultScene(result)
            } else {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(GameBoyPalette.mid)
            }
        }
        .frame(height: 305)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(GameBoyPalette.dark, lineWidth: 3)
        }
        .padding(10)
        .background(GameBoyPalette.bezel, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
    }

    private func encounterScene(_ species: PokemonSpecies) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(species.name.uppercased())
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                    Text("Nº \(String(format: "%03d", species.id))  •  \(species.rarity.localizedName.uppercased())")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("CAPTURA")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                    Text("\(Int((game.captureChance(for: species) * 100).rounded()))%")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                }
            }
            .padding(.horizontal, 17)
            .padding(.top, 15)

            Spacer(minLength: 0)
            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(GameBoyPalette.mid.opacity(0.45))
                    .frame(width: 220, height: 36)
                    .offset(y: -8)
                Image(species.spriteName)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 192, height: 192)
                    .offset(y: -15)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            HStack {
                Text(game.encounterAttempts == 0 ? "★  1ª FALHA: SEM FUGA" : "★  TENTATIVA \(game.encounterAttempts + 1)")
                Spacer()
                if let ends = game.encounterEndsAt {
                    Text("FUGIRÁ \(ends, style: .relative)")
                }
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .padding(.horizontal, 17)
            .padding(.bottom, 13)
        }
    }

    private func resultScene(_ result: EncounterResult) -> some View {
        VStack(spacing: 11) {
            Image(result.species.spriteName)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 150, height: 150)
                .opacity(result.ending == .caught ? 1 : 0.55)
                .accessibilityHidden(true)
            Text(result.species.name.uppercased())
                .font(.system(size: 24, weight: .black, design: .monospaced))
            Text(NSLocalizedString(result.ending == .caught ? "REGISTRADO NA POKÉDEX" : "O ENCONTRO TERMINOU", comment: "Encounter result heading"))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dialogue: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 18))
            Text(dialogueText)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .black))
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .frame(height: 60, alignment: .top)
        .background(GameBoyPalette.light, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(GameBoyPalette.dark, lineWidth: 3))
    }

    private var dialogueText: String {
        if let result = game.encounterResult {
            switch result.ending {
            case .caught: return String(format: NSLocalizedString("Conseguiu! %@ foi capturado.", comment: "Captured Pokémon"), result.species.name)
            case .fled: return String(format: NSLocalizedString("Oh não! %@ fugiu após a tentativa.", comment: "Pokémon fled"), result.species.name)
            case .ran: return NSLocalizedString("Você fugiu em segurança. Até o próximo encontro!", comment: "Player ran from encounter")
            case .expired: return NSLocalizedString("O tempo acabou. O Pokémon foi embora.", comment: "Encounter expired")
            }
        }
        if game.pokeballs == 0 { return NSLocalizedString("Sem Pokébolas! Espere a próxima recarga ou fuja.", comment: "No Poké Balls") }
        return battleMessage
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if let species = game.currentEncounter {
                Button(action: { throwBall(at: species) }) {
                    HStack(spacing: 10) {
                        PokeballMark()
                            .frame(width: 23, height: 23)
                        Text(NSLocalizedString(isThrowing ? "LANÇANDO…" : "CAPTURAR", comment: "Catch button state"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(game.pokeballs == 0 || isThrowing)
                .buttonStyle(GameBoyButtonStyle(isPrimary: true))

                Button("FUGIR") { game.runFromEncounter() }
                    .frame(maxWidth: .infinity)
                    .disabled(isThrowing)
                    .buttonStyle(GameBoyButtonStyle(isPrimary: false))
            } else {
                Button("CONTINUAR") {
                    game.dismissEncounterResult()
                    close()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(GameBoyButtonStyle(isPrimary: true))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            PokeballMark().frame(width: 18, height: 18)
            Text("\(game.pokeballs)/\(GameController.maximumPokeballs) POKÉBOLAS")
                .font(.system(size: 11, weight: .black, design: .monospaced))
            Spacer()
            if let refill = game.pokeballsRefillAt {
                Text("RECARGA \(refill, style: .relative)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            } else {
                Text("ESTOQUE CHEIO")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
        }
        .foregroundStyle(GameBoyPalette.mid)
    }

    private func throwBall(at species: PokemonSpecies) {
        guard game.pokeballs > 0, !isThrowing else { return }
        isThrowing = true
        battleMessage = NSLocalizedString("Você lançou uma Pokébola…", comment: "Poké Ball thrown")
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(750))
            guard game.currentEncounter?.id == species.id else {
                isThrowing = false
                return
            }
            switch game.throwPokeball() {
            case .brokeFree: battleMessage = NSLocalizedString("Quase! O Pokémon escapou da Pokébola.", comment: "Pokémon broke free")
            case .noBalls: battleMessage = NSLocalizedString("Suas Pokébolas acabaram.", comment: "No Poké Balls")
            case .caught, .fled, .unavailable: break
            }
            isThrowing = false
        }
    }
}

struct PokeballMark: View {
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle().fill(.white)
                UnevenRoundedRectangle(topLeadingRadius: size / 2, topTrailingRadius: size / 2)
                    .fill(GameBoyPalette.action)
                    .frame(height: size / 2)
                    .frame(maxHeight: .infinity, alignment: .top)
                Rectangle().fill(GameBoyPalette.dark).frame(height: size * 0.16)
                Circle().fill(.white)
                    .frame(width: size * 0.29, height: size * 0.29)
                    .overlay(Circle().strokeBorder(GameBoyPalette.dark, lineWidth: max(1, size * 0.10)))
                Circle().strokeBorder(GameBoyPalette.dark, lineWidth: max(1, size * 0.08))
            }
            .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }
}

private struct GameBoyButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .black, design: .monospaced))
            .foregroundStyle(isPrimary ? .white : GameBoyPalette.dark)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(isPrimary ? GameBoyPalette.action : GameBoyPalette.light, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(GameBoyPalette.dark, lineWidth: 3))
            .offset(y: configuration.isPressed ? 2 : 0)
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}
