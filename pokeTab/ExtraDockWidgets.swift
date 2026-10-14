import SwiftUI

struct DollarDockWidgetView: View {
    let isPreview: Bool
    @ObservedObject private var dollar = DollarController.shared

    var body: some View {
        Button { dollar.refresh(force: true) } label: {
            HStack(spacing: 8) {
                Image(systemName: "dollarsign.circle").font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("USD/BRL · referência").font(.caption2).opacity(0.8)
                    Text(dollar.quote.map { "R$ \($0.rate.formatted(.number.precision(.fractionLength(4))))" } ?? (dollar.errorMessage ?? NSLocalizedString("Carregando…", comment: "Loading dollar quote")))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .lineLimit(1)
                    if let quote = dollar.quote {
                        Text(quote.date).font(.system(size: 9)).opacity(0.75)
                    }
                }
            }
            .frame(width: 155, height: DockMetrics.itemHeight)
        }
        .buttonStyle(DockWidgetButtonStyle())
        .help("Cotação de referência diária da Frankfurter. Toque para atualizar; não é preço de negociação.")
        .disabled(isPreview)
        .onAppear { dollar.refresh() }
    }
}

struct BudgetDockWidgetView: View {
    let isPreview: Bool
    @ObservedObject private var budget = BudgetController.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button { openWindow(id: "finance") } label: {
            DockWidgetLabel(
                symbol: "chart.pie.fill",
                title: NSLocalizedString("Finanças · mês", comment: "Budget widget title"),
                detail: budget.monthlyBudgetCents == 0 ? NSLocalizedString("Definir limite", comment: "Set monthly budget") : BudgetController.money(budget.remainingCents),
                width: 150
            )
        }
        .buttonStyle(DockWidgetButtonStyle())
        .disabled(isPreview)
        .help("Saldo do orçamento mensal. Toque para registrar despesas.")
    }
}

struct FocusDockWidgetView: View {
    let isPreview: Bool
    @ObservedObject private var productivity = ProductivityController.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 2) {
            Button { openWindow(id: "productivity") } label: {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    DockWidgetLabel(
                        symbol: "timer",
                        title: NSLocalizedString("Foco", comment: "Focus widget title"),
                        detail: timeText(productivity.focusRemaining(at: context.date)),
                        width: 104
                    )
                }
            }
            .buttonStyle(.plain)
            Button { productivity.toggleFocus() } label: {
                Image(systemName: productivity.focusEndsAt == nil ? "play.fill" : "pause.fill")
                    .frame(width: 24, height: 36)
            }
            .buttonStyle(.plain)
        }
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))
        .disabled(isPreview)
        .help("Iniciar ou pausar uma sessão de foco")
    }

    private func timeText(_ seconds: TimeInterval) -> String {
        let value = Int(seconds.rounded(.up))
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}

struct TasksDockWidgetView: View {
    let isPreview: Bool
    @ObservedObject private var productivity = ProductivityController.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button { openWindow(id: "productivity") } label: {
            DockWidgetLabel(symbol: "checklist", title: NSLocalizedString("Tarefas", comment: "Tasks widget title"), detail: productivity.openTaskCount == 1 ? NSLocalizedString("1 pendente", comment: "One pending task") : String(format: NSLocalizedString("%d pendentes", comment: "Pending task count"), productivity.openTaskCount), width: 115)
        }
        .buttonStyle(DockWidgetButtonStyle())
        .disabled(isPreview)
    }
}

struct NotesDockWidgetView: View {
    let isPreview: Bool
    @ObservedObject private var productivity = ProductivityController.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button { openWindow(id: "productivity") } label: {
            DockWidgetLabel(
                symbol: "note.text",
                title: NSLocalizedString("Notas rápidas", comment: "Quick notes widget title"),
                detail: productivity.note.isEmpty ? NSLocalizedString("Escrever nota", comment: "Write a note") : productivity.note.components(separatedBy: .newlines).first ?? NSLocalizedString("Abrir nota", comment: "Open note"),
                width: 140
            )
        }
        .buttonStyle(DockWidgetButtonStyle())
        .disabled(isPreview)
    }
}

private struct DockWidgetLabel: View {
    let symbol: String
    let title: String
    let detail: String
    let width: CGFloat

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption2.bold()).opacity(0.8)
                Text(detail)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
        }
        .frame(width: width, height: DockMetrics.itemHeight)
    }
}

struct DockWidgetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.white.opacity(configuration.isPressed ? 0.25 : 0.12), in: RoundedRectangle(cornerRadius: 15))
    }
}

struct FinanceView: View {
    @ObservedObject private var budget = BudgetController.shared
    @State private var budgetInput = ""
    @State private var expenseTitle = ""
    @State private var expenseAmount = ""
    @State private var inputError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Finanças").font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Acompanhe um orçamento mensal simples. Os valores ficam salvos apenas neste Mac.")
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    summary("Limite", BudgetController.money(budget.monthlyBudgetCents))
                    summary("Gasto no mês", BudgetController.money(budget.spentThisMonthCents))
                    summary("Restante", BudgetController.money(budget.remainingCents))
                }

                Divider()
                Text("Orçamento mensal").font(.headline)
                HStack {
                    TextField("Limite em R$", text: $budgetInput)
                    Button("Salvar limite") {
                        inputError = !budget.setBudget(budgetInput)
                    }
                }
                Text("Despesas registradas continuam no histórico quando você altera o limite.")
                    .font(.caption).foregroundStyle(.secondary)

                Divider()
                Text("Nova despesa").font(.headline)
                HStack {
                    TextField("Descrição", text: $expenseTitle)
                    TextField("Valor em R$", text: $expenseAmount).frame(width: 125)
                    Button("Adicionar") {
                        inputError = !budget.addExpense(title: expenseTitle, amount: expenseAmount)
                        if !inputError { expenseTitle = ""; expenseAmount = "" }
                    }
                }
                if inputError { Text("Confira o valor e a descrição. Use o separador decimal do sistema para os centavos.").foregroundStyle(.red).font(.caption) }

                Text("Lançamentos").font(.headline)
                if budget.expenses.isEmpty {
                    Text("Nenhuma despesa registrada.").foregroundStyle(.secondary)
                }
                ForEach(budget.expenses) { expense in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(expense.title)
                            Text(expense.date, style: .date).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(BudgetController.money(expense.amountCents)).monospacedDigit()
                        Button("Remover", systemImage: "trash") { budget.removeExpense(expense) }
                            .labelStyle(.iconOnly)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(26)
        }
        .frame(minWidth: 560, minHeight: 560)
        .onAppear { budgetInput = (Double(budget.monthlyBudgetCents) / 100).formatted(.number.precision(.fractionLength(2)).locale(.current)) }
    }

    private func summary(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(NSLocalizedString(title, comment: "Budget summary")).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ProductivityView: View {
    @ObservedObject private var productivity = ProductivityController.shared
    @State private var newTask = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Produtividade").font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Foco, tarefas e uma nota rápida, disponíveis direto na barra.")
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Foco").font(.headline)
                    Spacer()
                    Picker("Duração", selection: $productivity.focusMinutes) {
                        Text("25 min").tag(25)
                        Text("50 min").tag(50)
                    }
                    .frame(width: 155)
                }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let value = Int(productivity.focusRemaining(at: context.date).rounded(.up))
                    Text(String(format: "%02d:%02d", value / 60, value % 60))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                HStack {
                    Button(productivity.focusEndsAt == nil ? "Iniciar foco" : "Pausar") { productivity.toggleFocus() }
                        .buttonStyle(.borderedProminent)
                    Button("Reiniciar") { productivity.resetFocus() }
                }

                Divider()
                Text("Tarefas").font(.headline)
                HStack {
                    TextField("Nova tarefa", text: $newTask)
                        .onSubmit { addTask() }
                    Button("Adicionar") { addTask() }
                }
                ForEach(productivity.tasks) { task in
                    HStack {
                        Button { productivity.toggleTask(task) } label: {
                            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        }
                        .buttonStyle(.plain)
                        Text(task.title)
                            .strikethrough(task.isDone)
                            .foregroundStyle(task.isDone ? .secondary : .primary)
                        Spacer()
                        Button("Remover", systemImage: "trash") { productivity.removeTask(task) }
                            .labelStyle(.iconOnly)
                    }
                }

                Divider()
                Text("Nota rápida").font(.headline)
                TextEditor(text: $productivity.note)
                    .font(.body)
                    .frame(minHeight: 130)
                    .padding(5)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(26)
        }
        .frame(minWidth: 520, minHeight: 600)
    }

    private func addTask() {
        productivity.addTask(newTask)
        newTask = ""
    }
}
