import SwiftUI

enum Rarity: String, CaseIterable {
    case common = "Comum"
    case uncommon = "Incomum"
    case rare = "Raro"
    case special = "Especial"

    var localizedName: String { NSLocalizedString(rawValue, comment: "Pokémon rarity") }

    var color: Color {
        switch self {
        case .common: .gray
        case .uncommon: .teal
        case .rare: .purple
        case .special: .orange
        }
    }

    var baseCaptureChance: Double {
        switch self {
        case .common: 0.72
        case .uncommon: 0.50
        case .rare: 0.30
        case .special: 0.16
        }
    }

    var baseFleeChance: Double {
        switch self {
        case .common: 0.08
        case .uncommon: 0.16
        case .rare: 0.28
        case .special: 0.42
        }
    }
}

struct PokemonSpecies: Identifiable, Hashable {
    let id: Int
    let name: String
    let rarity: Rarity

    var spriteName: String { "pokemon-\(id)" }

    var encounterWeight: Double {
        switch id {
        case 16, 19, 21, 41, 72: 5 // Pidgey e Rattata
        case 10, 13, 29, 32, 43, 50, 69, 74, 109, 129: 2 // Encontros comuns das primeiras rotas
        default: 1
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum PokemonCatalog {
    private static let names = """
    Bulbasaur
    Ivysaur
    Venusaur
    Charmander
    Charmeleon
    Charizard
    Squirtle
    Wartortle
    Blastoise
    Caterpie
    Metapod
    Butterfree
    Weedle
    Kakuna
    Beedrill
    Pidgey
    Pidgeotto
    Pidgeot
    Rattata
    Raticate
    Spearow
    Fearow
    Ekans
    Arbok
    Pikachu
    Raichu
    Sandshrew
    Sandslash
    Nidoran♀
    Nidorina
    Nidoqueen
    Nidoran♂
    Nidorino
    Nidoking
    Clefairy
    Clefable
    Vulpix
    Ninetales
    Jigglypuff
    Wigglytuff
    Zubat
    Golbat
    Oddish
    Gloom
    Vileplume
    Paras
    Parasect
    Venonat
    Venomoth
    Diglett
    Dugtrio
    Meowth
    Persian
    Psyduck
    Golduck
    Mankey
    Primeape
    Growlithe
    Arcanine
    Poliwag
    Poliwhirl
    Poliwrath
    Abra
    Kadabra
    Alakazam
    Machop
    Machoke
    Machamp
    Bellsprout
    Weepinbell
    Victreebel
    Tentacool
    Tentacruel
    Geodude
    Graveler
    Golem
    Ponyta
    Rapidash
    Slowpoke
    Slowbro
    Magnemite
    Magneton
    Farfetch'd
    Doduo
    Dodrio
    Seel
    Dewgong
    Grimer
    Muk
    Shellder
    Cloyster
    Gastly
    Haunter
    Gengar
    Onix
    Drowzee
    Hypno
    Krabby
    Kingler
    Voltorb
    Electrode
    Exeggcute
    Exeggutor
    Cubone
    Marowak
    Hitmonlee
    Hitmonchan
    Lickitung
    Koffing
    Weezing
    Rhyhorn
    Rhydon
    Chansey
    Tangela
    Kangaskhan
    Horsea
    Seadra
    Goldeen
    Seaking
    Staryu
    Starmie
    Mr. Mime
    Scyther
    Jynx
    Electabuzz
    Magmar
    Pinsir
    Tauros
    Magikarp
    Gyarados
    Lapras
    Ditto
    Eevee
    Vaporeon
    Jolteon
    Flareon
    Porygon
    Omanyte
    Omastar
    Kabuto
    Kabutops
    Aerodactyl
    Snorlax
    Articuno
    Zapdos
    Moltres
    Dratini
    Dragonair
    Dragonite
    Mewtwo
    Mew
    """.split(separator: "\n").map(String.init)

    private static let rareIDs: Set<Int> = [3, 6, 9, 31, 34, 38, 59, 65, 68, 94, 106, 107, 113, 115, 123, 124, 125, 126, 127, 130, 131, 132, 137, 139, 141, 142, 143]
    private static let specialIDs: Set<Int> = Set(144...151)
    private static let uncommonIDs: Set<Int> = [2, 5, 8, 12, 15, 18, 22, 24, 25, 26, 28, 30, 33, 35, 36, 37, 40, 42, 45, 47, 49, 51, 53, 55, 57, 61, 62, 64, 67, 71, 73, 76, 78, 80, 82, 83, 85, 87, 89, 91, 93, 95, 97, 99, 101, 103, 105, 109, 110, 112, 117, 119, 121, 122, 129, 133, 134, 135, 136, 138, 140]

    static let all: [PokemonSpecies] = names.enumerated().map { index, name in
        let id = index + 1
        let rarity: Rarity = specialIDs.contains(id) ? .special : rareIDs.contains(id) ? .rare : uncommonIDs.contains(id) ? .uncommon : .common
        return PokemonSpecies(id: id, name: name, rarity: rarity)
    }
}
