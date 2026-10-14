import Combine
import Foundation
import SwiftUI

struct DollarQuote: Codable {
    let date: String
    let rate: Double
}

@MainActor
final class DollarController: ObservableObject {
    static let shared = DollarController()
    @Published private(set) var quote: DollarQuote?
    @Published private(set) var errorMessage: String?
    private var lastAttempt: Date?
    private var isLoading = false

    private init() {
        if let data = UserDefaults.standard.data(forKey: "dollarQuote.v1") {
            quote = try? JSONDecoder().decode(DollarQuote.self, from: data)
        }
    }

    func refresh(force: Bool = false) {
        guard !isLoading else { return }
        if !force, let lastAttempt, Date().timeIntervalSince(lastAttempt) < 3600 { return }
        lastAttempt = Date()
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let url = URL(string: "https://api.frankfurter.dev/v2/rate/usd/brl")!
                let (data, response) = try await URLSession.shared.data(from: url)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                let updated = try JSONDecoder().decode(DollarQuote.self, from: data)
                guard updated.rate.isFinite && updated.rate > 0 else { throw URLError(.cannotParseResponse) }
                quote = updated
                errorMessage = nil
                UserDefaults.standard.set(data, forKey: "dollarQuote.v1")
            } catch {
                errorMessage = NSLocalizedString(quote == nil ? "Sem conexão" : "Última cotação salva", comment: "Dollar quote error")
            }
        }
    }
}

struct Expense: Codable, Identifiable {
    var id = UUID()
    let title: String
    let amountCents: Int
    let date: Date
}

@MainActor
final class BudgetController: ObservableObject {
    static let shared = BudgetController()
    @Published private(set) var monthlyBudgetCents: Int = 0
    @Published private(set) var expenses: [Expense] = []

    private init() {
        monthlyBudgetCents = UserDefaults.standard.integer(forKey: "monthlyBudgetCents.v1")
        if let data = UserDefaults.standard.data(forKey: "budgetExpenses.v1") {
            expenses = (try? JSONDecoder().decode([Expense].self, from: data)) ?? []
        }
    }

    var spentThisMonthCents: Int {
        guard let month = Calendar.current.dateInterval(of: .month, for: Date()) else { return 0 }
        return expenses.filter { month.contains($0.date) }.reduce(0) { $0 + $1.amountCents }
    }

    var remainingCents: Int { monthlyBudgetCents - spentThisMonthCents }

    func setBudget(_ text: String) -> Bool {
        guard let cents = Self.parseCents(text, allowZero: true) else { return false }
        monthlyBudgetCents = cents
        UserDefaults.standard.set(cents, forKey: "monthlyBudgetCents.v1")
        return true
    }

    func addExpense(title: String, amount: String) -> Bool {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, let cents = Self.parseCents(amount, allowZero: false) else { return false }
        expenses.insert(Expense(title: cleaned, amountCents: cents, date: Date()), at: 0)
        persistExpenses()
        return true
    }

    func removeExpense(_ expense: Expense) {
        expenses.removeAll { $0.id == expense.id }
        persistExpenses()
    }

    static func money(_ cents: Int) -> String {
        (Double(cents) / 100).formatted(.currency(code: "BRL"))
    }

    private static func parseCents(_ text: String, allowZero: Bool) -> Int? {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        guard let number = formatter.number(from: text), number.doubleValue.isFinite else { return nil }
        let cents = (number.doubleValue * 100).rounded()
        guard cents >= (allowZero ? 0 : 1), cents <= Double(Int.max / 4) else { return nil }
        return Int(cents)
    }

    private func persistExpenses() {
        if let data = try? JSONEncoder().encode(expenses) {
            UserDefaults.standard.set(data, forKey: "budgetExpenses.v1")
        }
    }
}

struct QuickTask: Codable, Identifiable {
    var id = UUID()
    let title: String
    var isDone = false
}

@MainActor
final class ProductivityController: ObservableObject {
    static let shared = ProductivityController()
    @Published private(set) var tasks: [QuickTask] = []
    @Published var note = "" {
        didSet { UserDefaults.standard.set(note, forKey: "quickNote.v1") }
    }
    @Published private(set) var focusEndsAt: Date?
    @Published private(set) var pausedFocusSeconds: TimeInterval = 25 * 60
    @Published var focusMinutes: Int = 25 {
        didSet {
            UserDefaults.standard.set(focusMinutes, forKey: "focusMinutes.v1")
            resetFocus()
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        note = defaults.string(forKey: "quickNote.v1") ?? ""
        let savedMinutes = defaults.integer(forKey: "focusMinutes.v1")
        focusMinutes = [25, 50].contains(savedMinutes) ? savedMinutes : 25
        pausedFocusSeconds = defaults.object(forKey: "pausedFocusSeconds.v1") as? Double ?? Double(focusMinutes * 60)
        focusEndsAt = defaults.object(forKey: "focusEndsAt.v1") as? Date
        if let data = defaults.data(forKey: "quickTasks.v1") {
            tasks = (try? JSONDecoder().decode([QuickTask].self, from: data)) ?? []
        }
    }

    var openTaskCount: Int { tasks.filter { !$0.isDone }.count }

    func focusRemaining(at date: Date) -> TimeInterval {
        max(0, focusEndsAt.map { $0.timeIntervalSince(date) } ?? pausedFocusSeconds)
    }

    func toggleFocus() {
        if let end = focusEndsAt {
            pausedFocusSeconds = max(0, end.timeIntervalSinceNow)
            focusEndsAt = nil
        } else {
            if pausedFocusSeconds <= 0 { pausedFocusSeconds = Double(focusMinutes * 60) }
            focusEndsAt = Date().addingTimeInterval(pausedFocusSeconds)
        }
        persistFocus()
    }

    func resetFocus() {
        focusEndsAt = nil
        pausedFocusSeconds = Double(focusMinutes * 60)
        persistFocus()
    }

    func addTask(_ title: String) {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        tasks.append(QuickTask(title: cleaned))
        persistTasks()
    }

    func toggleTask(_ task: QuickTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isDone.toggle()
        persistTasks()
    }

    func removeTask(_ task: QuickTask) {
        tasks.removeAll { $0.id == task.id }
        persistTasks()
    }

    private func persistFocus() {
        UserDefaults.standard.set(focusEndsAt, forKey: "focusEndsAt.v1")
        UserDefaults.standard.set(pausedFocusSeconds, forKey: "pausedFocusSeconds.v1")
    }

    private func persistTasks() {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: "quickTasks.v1")
        }
    }
}
