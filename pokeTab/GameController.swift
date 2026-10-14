import AppKit
import Combine
import Foundation

struct PokemonProgress: Codable {
    var seenCount = 0
    var caughtCount = 0
    var lastSeen: Date?
}

enum EncounterFrequency: String, CaseIterable, Identifiable {
    case calm = "Tranquila"
    case normal = "Normal"
    case lively = "Animada"

    var id: String { rawValue }
    var localizedName: String { NSLocalizedString(rawValue, comment: "Encounter frequency") }

    var interval: ClosedRange<TimeInterval> {
        switch self {
        case .calm: 45 * 60...70 * 60
        case .normal: 20 * 60...35 * 60
        case .lively: 10 * 60...20 * 60
        }
    }

    var description: String {
        switch self {
        case .calm: NSLocalizedString("Próximo encontro em cerca de 45 a 70 minutos", comment: "Calm encounter frequency")
        case .normal: NSLocalizedString("Próximo encontro em cerca de 20 a 35 minutos", comment: "Normal encounter frequency")
        case .lively: NSLocalizedString("Próximo encontro em cerca de 10 a 20 minutos", comment: "Lively encounter frequency")
        }
    }
}

enum EncounterEnding {
    case caught, fled, ran, expired
}

struct EncounterResult {
    let species: PokemonSpecies
    let ending: EncounterEnding
}

enum ThrowResult {
    case caught, brokeFree, fled, noBalls, unavailable
}

@MainActor
final class GameController: ObservableObject {
    static let shared = GameController()
    static let maximumPokeballs = 10
    static let refillInterval: TimeInterval = 2 * 3600

    @Published private(set) var progress: [Int: PokemonProgress] = [:]
    @Published private(set) var currentEncounter: PokemonSpecies?
    @Published private(set) var encounterEndsAt: Date?
    @Published private(set) var nextEncounterAt: Date?
    @Published private(set) var encounterResult: EncounterResult?
    @Published private(set) var pokeballs = maximumPokeballs
    @Published private(set) var pokeballsRefillAt: Date?
    @Published private(set) var encounterAttempts = 0
    @Published var isPaused: Bool {
        didSet {
            defaults.set(isPaused, forKey: Keys.paused)
            if isPaused {
                if currentEncounter != nil { expireEncounter() }
                else {
                    nextEncounterAt = nil
                    defaults.removeObject(forKey: Keys.next)
                }
            }
            else if nextEncounterAt == nil { scheduleNextEncounter() }
        }
    }
    @Published var frequency: EncounterFrequency {
        didSet {
            defaults.set(frequency.rawValue, forKey: Keys.frequency)
            scheduleNextEncounter()
        }
    }

    private enum Keys {
        static let progress = "pokemonProgress.v1"
        static let paused = "encountersPaused.v1"
        static let frequency = "encounterFrequency.v1"
        static let next = "nextEncounterAt.v1"
        static let active = "activeEncounterID.v1"
        static let ends = "activeEncounterEndsAt.v1"
        static let activeSeen = "activeEncounterSeen.v1"
        static let attempts = "activeEncounterAttempts.v1"
        static let pokeballs = "pokeballsRemaining.v1"
        static let refill = "pokeballsRefillAt.v1"
        static let scheduleVersion = "encounterScheduleVersion"
    }

    private let defaults = UserDefaults.standard
    private var timer: Timer?

    private init() {
        let isFirstLaunch = defaults.object(forKey: Keys.next) == nil
            && defaults.object(forKey: Keys.progress) == nil
            && defaults.object(forKey: Keys.frequency) == nil
        isPaused = defaults.bool(forKey: Keys.paused)
        frequency = EncounterFrequency(rawValue: defaults.string(forKey: Keys.frequency) ?? "") ?? .normal
        pokeballs = min(Self.maximumPokeballs, max(0, defaults.object(forKey: Keys.pokeballs) as? Int ?? Self.maximumPokeballs))
        pokeballsRefillAt = defaults.object(forKey: Keys.refill) as? Date
        if pokeballs < Self.maximumPokeballs && pokeballsRefillAt == nil { pokeballs = Self.maximumPokeballs }
        if let data = defaults.data(forKey: Keys.progress), let saved = try? JSONDecoder().decode([Int: PokemonProgress].self, from: data) {
            progress = saved
        }
        nextEncounterAt = defaults.object(forKey: Keys.next) as? Date
        if let id = defaults.object(forKey: Keys.active) as? Int,
           let ends = defaults.object(forKey: Keys.ends) as? Date,
           ends > Date() {
            currentEncounter = PokemonCatalog.all.first { $0.id == id }
            encounterEndsAt = ends
            encounterAttempts = max(0, defaults.integer(forKey: Keys.attempts))
        } else {
            defaults.removeObject(forKey: Keys.active)
            defaults.removeObject(forKey: Keys.ends)
            defaults.removeObject(forKey: Keys.attempts)
        }
        refreshPokeballs()
        if currentEncounter == nil && !isPaused {
            if defaults.integer(forKey: Keys.scheduleVersion) < 2,
               nextEncounterAt.map({ $0 > Date() }) ?? true {
                scheduleNextEncounter(initial: isFirstLaunch)
            } else if nextEncounterAt == nil {
                scheduleNextEncounter()
            }
        }
        defaults.set(2, forKey: Keys.scheduleVersion)
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            guard let controller = self else { return }
            Task { @MainActor in controller.tick() }
        }
        updateDockTile()
    }

    var seenCount: Int { progress.values.filter { $0.seenCount > 0 }.count }
    var caughtCount: Int { progress.values.filter { $0.caughtCount > 0 }.count }
    var duplicateCount: Int { progress.values.reduce(0) { $0 + max(0, $1.caughtCount - 1) } }

    func progress(for species: PokemonSpecies) -> PokemonProgress { progress[species.id] ?? PokemonProgress() }

    func tick() {
        let now = Date()
        refreshPokeballs(at: now)
        if let ends = encounterEndsAt, now >= ends { expireEncounter() }
        if !isPaused, currentEncounter == nil, let next = nextEncounterAt, now >= next { spawnEncounter() }
    }

    func simulateEncounter() {
        guard !isPaused else { return }
        expireEncounter()
        spawnEncounter()
    }

    func markCurrentEncounterSeen() {
        guard let species = currentEncounter, !defaults.bool(forKey: Keys.activeSeen) else { return }
        var record = progress[species.id] ?? PokemonProgress()
        record.seenCount += 1
        record.lastSeen = Date()
        progress[species.id] = record
        defaults.set(true, forKey: Keys.activeSeen)
        persistProgress()
    }

    func captureChance(for species: PokemonSpecies) -> Double {
        min(0.90, species.rarity.baseCaptureChance + Double(encounterAttempts) * 0.08)
    }

    @discardableResult
    func throwPokeball() -> ThrowResult {
        let now = Date()
        refreshPokeballs(at: now)
        guard let species = currentEncounter else { return .unavailable }
        if let ends = encounterEndsAt, now >= ends {
            expireEncounter()
            return .unavailable
        }
        guard pokeballs > 0 else { return .noBalls }

        let chance = captureChance(for: species)
        pokeballs -= 1
        if pokeballsRefillAt == nil { pokeballsRefillAt = now.addingTimeInterval(Self.refillInterval) }
        persistPokeballs()

        if Double.random(in: 0..<1) < chance {
            var record = progress[species.id] ?? PokemonProgress()
            record.caughtCount += 1
            progress[species.id] = record
            persistProgress()
            finishEncounter(species: species, ending: .caught)
            return .caught
        }

        encounterAttempts += 1
        defaults.set(encounterAttempts, forKey: Keys.attempts)
        // A primeira falha sempre dá ao jogador outra chance de tentar.
        let fleeChance = min(0.65, species.rarity.baseFleeChance + Double(max(0, encounterAttempts - 2)) * 0.05)
        if encounterAttempts >= 2 && Double.random(in: 0..<1) < fleeChance {
            finishEncounter(species: species, ending: .fled)
            return .fled
        }
        return .brokeFree
    }

    func runFromEncounter() {
        guard let species = currentEncounter else { return }
        finishEncounter(species: species, ending: .ran)
    }

    func dismissEncounterResult() { encounterResult = nil }

    func expireEncounter() {
        guard let species = currentEncounter else { return }
        finishEncounter(species: species, ending: .expired)
    }

    private func finishEncounter(species: PokemonSpecies, ending: EncounterEnding) {
        encounterResult = EncounterResult(species: species, ending: ending)
        currentEncounter = nil
        encounterEndsAt = nil
        encounterAttempts = 0
        defaults.removeObject(forKey: Keys.active)
        defaults.removeObject(forKey: Keys.ends)
        defaults.removeObject(forKey: Keys.activeSeen)
        defaults.removeObject(forKey: Keys.attempts)
        updateDockTile()
        if !isPaused { scheduleNextEncounter() }
        else {
            nextEncounterAt = nil
            defaults.removeObject(forKey: Keys.next)
        }
    }

    private func scheduleNextEncounter(initial: Bool = false) {
        guard !isPaused else { return }
        let interval: ClosedRange<TimeInterval> = initial ? 2 * 60...4 * 60 : frequency.interval
        let next = Date().addingTimeInterval(Double.random(in: interval))
        nextEncounterAt = next
        defaults.set(next, forKey: Keys.next)
    }

    private func spawnEncounter() {
        guard !isPaused, currentEncounter == nil else { return }
        let species = chooseSpecies()
        encounterResult = nil
        encounterAttempts = 0
        currentEncounter = species
        let ends = Date().addingTimeInterval(5 * 60)
        encounterEndsAt = ends
        nextEncounterAt = nil
        defaults.removeObject(forKey: Keys.next)
        defaults.set(species.id, forKey: Keys.active)
        defaults.set(ends, forKey: Keys.ends)
        defaults.set(false, forKey: Keys.activeSeen)
        defaults.removeObject(forKey: Keys.attempts)
        updateDockTile()
    }

    private func refreshPokeballs(at now: Date = Date()) {
        guard let refill = pokeballsRefillAt else { return }
        if now >= refill {
            pokeballs = Self.maximumPokeballs
            pokeballsRefillAt = nil
            persistPokeballs()
        }
    }

    private func persistPokeballs() {
        defaults.set(pokeballs, forKey: Keys.pokeballs)
        if let pokeballsRefillAt { defaults.set(pokeballsRefillAt, forKey: Keys.refill) }
        else { defaults.removeObject(forKey: Keys.refill) }
    }

    private func chooseSpecies() -> PokemonSpecies {
        let tierRoll = Double.random(in: 0..<1)
        let rarity: Rarity = tierRoll < 0.72 ? .common
            : tierRoll < 0.92 ? .uncommon
            : tierRoll < 0.99 ? .rare : .special
        let candidates = PokemonCatalog.all.filter { $0.rarity == rarity }
        let weights = candidates.map { species in
            species.encounterWeight * (progress(for: species).caughtCount == 0 ? 1.4 : 1)
        }
        let total = weights.reduce(0, +)
        var roll = Double.random(in: 0..<total)
        for (species, weight) in zip(candidates, weights) {
            roll -= weight
            if roll < 0 { return species }
        }
        return candidates[0]
    }

    private func persistProgress() {
        if let data = try? JSONEncoder().encode(progress) { defaults.set(data, forKey: Keys.progress) }
    }

    private func updateDockTile() {
        let tile = NSApp.dockTile
        tile.contentView = DockTileView(species: currentEncounter)
        tile.badgeLabel = currentEncounter == nil ? nil : "!"
        tile.display()
    }
}

private final class DockTileView: NSView {
    private let species: PokemonSpecies?

    init(species: PokemonSpecies?) {
        self.species = species
        super.init(frame: NSRect(x: 0, y: 0, width: 128, height: 128))
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        NSApp.applicationIconImage.draw(in: bounds)
        if let species {
            let spotlight = NSBezierPath(ovalIn: NSRect(x: 12, y: 35, width: 104, height: 86))
            NSColor.white.withAlphaComponent(0.48).setFill()
            spotlight.fill()
            if let sprite = NSImage(named: NSImage.Name(species.spriteName)) {
                NSGraphicsContext.current?.imageInterpolation = .none
                sprite.draw(
                    in: NSRect(x: 16, y: 36, width: 96, height: 92),
                    from: .zero,
                    operation: .sourceOver,
                    fraction: 1
                )
            }
        }
    }
}
