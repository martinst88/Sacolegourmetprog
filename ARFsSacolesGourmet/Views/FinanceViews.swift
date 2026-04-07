import SwiftUI
import SwiftData
import Charts

private enum ExpenseStatusFilter: String, CaseIterable, Identifiable {
    case all = "Todos"
    case pending = "Pendentes"
    case overdue = "Vencidos"
    case paid = "Pagos"

    var id: String { rawValue }
}

struct FinanceHomeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PremiumCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Financeiro")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("Acompanhe despesas, fluxo financeiro e relatórios com a mesma leitura clara da operação.")
                            .foregroundStyle(AppTheme.textSecondary)

                        HStack(spacing: 10) {
                            StatusPill(text: "Entradas", color: AppTheme.success)
                            StatusPill(text: "Saídas", color: AppTheme.danger)
                            StatusPill(text: "Relatórios", color: AppTheme.brandBrown)
                        }
                    }
                }

                NavigationLink(destination: ExpensesView()) {
                    ModuleTile(
                        title: "Contas a Pagar",
                        subtitle: "Despesas, vencimentos e quitação com controle local.",
                        systemImage: "creditcard.fill",
                        tint: AppTheme.danger
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: FinanceDashboardView()) {
                    ModuleTile(
                        title: "Fluxo Financeiro",
                        subtitle: "Entradas, saídas, saldo e lucro do período.",
                        systemImage: "chart.line.uptrend.xyaxis.circle.fill",
                        tint: AppTheme.accent
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: ReportsView()) {
                    ModuleTile(
                        title: "Relatórios",
                        subtitle: "Análises visuais, CSV e visão gerencial simples.",
                        systemImage: "doc.text.magnifyingglass",
                        tint: AppTheme.brandBrown
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .navigationTitle("Financeiro")
        .brandPlainBackground()
    }
}

struct ExpensesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.dueDate) private var expenses: [Expense]

    @State private var filter: ExpenseStatusFilter = .all
    @State private var searchText = ""
    @State private var showingForm = false
    @State private var editingExpense: Expense?
    @State private var payingExpense: Expense?

    private var filteredExpenses: [Expense] {
        expenses.filter { expense in
            let matchesSearch = searchText.isEmpty || expense.title.localizedCaseInsensitiveContains(searchText)
            let matchesFilter: Bool
            switch filter {
            case .all:
                matchesFilter = true
            case .pending:
                matchesFilter = !expense.isPaid && expense.dueDate >= .now.startOfDayInBrazil
            case .overdue:
                matchesFilter = !expense.isPaid && expense.dueDate < .now.startOfDayInBrazil
            case .paid:
                matchesFilter = expense.isPaid
            }
            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Filtro", selection: $filter) {
                    ForEach(ExpenseStatusFilter.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }

            Section("Despesas") {
                ForEach(filteredExpenses, id: \.id) { expense in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(expense.title)
                                .font(.headline)
                            Spacer()
                            Text(expense.amount.brlCurrency)
                                .font(.headline)
                        }
                        Text("\(expense.category.rawValue) • vencimento em \(expense.dueDate.brDate)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(expense.statusLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(expense.isPaid ? AppTheme.success : (expense.dueDate < .now.startOfDayInBrazil ? AppTheme.danger : AppTheme.warning))
                        if !expense.isPaid {
                            Button("Marcar como paga") {
                                payingExpense = expense
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(AppTheme.cardBackground)
                    .swipeActions {
                        Button("Editar") {
                            editingExpense = expense
                            showingForm = true
                        }
                        .tint(AppTheme.accent)

                        Button("Excluir", role: .destructive) {
                            modelContext.delete(expense)
                            try? modelContext.saveChanges()
                        }
                    }
                }
            }
        }
        .navigationTitle("Contas a Pagar")
        .searchable(text: $searchText, prompt: "Buscar despesa")
        .listStyle(.insetGrouped)
        .brandScrollBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingExpense = nil
                    showingForm = true
                } label: {
                    Label("Nova despesa", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            NavigationStack {
                ExpenseFormView(expense: editingExpense)
            }
        }
        .sheet(isPresented: Binding(get: { payingExpense != nil }, set: { if !$0 { payingExpense = nil } })) {
            if let payingExpense {
                NavigationStack {
                    ExpensePaymentFormView(expense: payingExpense)
                }
            }
        }
    }
}

struct ExpenseFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let expense: Expense?

    @State private var title: String
    @State private var category: ExpenseCategory
    @State private var supplier: String
    @State private var amount: Double
    @State private var launchDate: Date
    @State private var dueDate: Date
    @State private var notes: String

    init(expense: Expense?) {
        self.expense = expense
        _title = State(initialValue: expense?.title ?? "")
        _category = State(initialValue: expense?.category ?? .other)
        _supplier = State(initialValue: expense?.supplier ?? "")
        _amount = State(initialValue: expense?.amount ?? 0)
        _launchDate = State(initialValue: expense?.launchDate ?? .now)
        _dueDate = State(initialValue: expense?.dueDate ?? .now)
        _notes = State(initialValue: expense?.notes ?? "")
    }

    var body: some View {
        Form {
            Section("Despesa") {
                TextField("Descrição", text: $title)
                Picker("Categoria", selection: $category) {
                    ForEach(ExpenseCategory.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                TextField("Fornecedor", text: $supplier)
                TextField("Valor", value: $amount, formatter: Formatters.decimal)
                    .keyboardType(.decimalPad)
                DatePicker("Data de lançamento", selection: $launchDate, displayedComponents: .date)
                DatePicker("Data de vencimento", selection: $dueDate, displayedComponents: .date)
                TextField("Observações", text: $notes, axis: .vertical)
            }
        }
        .navigationTitle(expense == nil ? "Nova Despesa" : "Editar Despesa")
        .brandScrollBackground()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") { save() }
            }
        }
    }

    private func save() {
        let model = expense ?? Expense(title: title, category: category, amount: amount, dueDate: dueDate)
        model.title = title
        model.category = category
        model.supplier = supplier
        model.amount = amount
        model.launchDate = launchDate
        model.dueDate = dueDate
        model.notes = notes
        if expense == nil {
            modelContext.insert(model)
        }
        try? modelContext.saveChanges()
        dismiss()
    }
}

struct ExpensePaymentFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let expense: Expense

    @State private var method: PaymentMethod = .pix
    @State private var paidAt = Date()

    var body: some View {
        Form {
            Section("Pagamento") {
                LabeledContent("Despesa", value: expense.title)
                LabeledContent("Valor", value: expense.amount.brlCurrency)
                Picker("Forma de pagamento", selection: $method) {
                    ForEach([PaymentMethod.pix, .cash, .card]) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                DatePicker("Data do pagamento", selection: $paidAt, displayedComponents: .date)
            }
        }
        .navigationTitle("Quitar Despesa")
        .brandScrollBackground()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") {
                    try? ExpenseService.markAsPaid(expense: expense, method: method, paidAt: paidAt, context: modelContext)
                    dismiss()
                }
            }
        }
    }
}

struct FinanceDashboardView: View {
    @Query(sort: \Sale.saleDate, order: .reverse) private var sales: [Sale]
    @Query(sort: \PaymentRecord.paymentDate, order: .reverse) private var payments: [PaymentRecord]
    @Query(sort: \Expense.launchDate, order: .reverse) private var expenses: [Expense]

    @StateObject private var viewModel = ReportsViewModel()

    private var summary: FinanceSummary {
        viewModel.financeSummary(sales: sales, payments: payments, expenses: expenses)
    }

    private var expenseChartData: [ExpenseCategorySummary] {
        FinanceService.expensesByCategory(expenses: expenses, range: viewModel.range())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PremiumCard(title: "Período") {
                    Picker("Período", selection: $viewModel.period) {
                        ForEach(AnalyticsPeriod.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    if viewModel.period == .custom {
                        DatePicker("Início", selection: $viewModel.customStart, displayedComponents: .date)
                        DatePicker("Fim", selection: $viewModel.customEnd, displayedComponents: .date)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    MetricCard(title: "Entradas", value: summary.entries.brlCurrency, subtitle: "recebimentos do período", color: AppTheme.success, systemImage: "arrow.down.circle")
                    MetricCard(title: "Saídas", value: summary.exits.brlCurrency, subtitle: "despesas pagas", color: AppTheme.danger, systemImage: "arrow.up.circle")
                    MetricCard(title: "Saldo", value: summary.balance.brlCurrency, subtitle: "fluxo de caixa", color: AppTheme.accent, systemImage: "equal.circle")
                    MetricCard(title: "Faturamento", value: summary.revenue.brlCurrency, subtitle: "vendas emitidas", color: AppTheme.highlight, systemImage: "banknote")
                    MetricCard(title: "Lucro Bruto", value: summary.grossProfit.brlCurrency, subtitle: "faturamento - CPV", color: AppTheme.brandBrown, systemImage: "chart.bar")
                    MetricCard(title: "Lucro Líquido", value: summary.netProfit.brlCurrency, subtitle: "após despesas operacionais", color: AppTheme.success, systemImage: "chart.line.uptrend.xyaxis")
                }

                PremiumCard(title: "Despesas por Categoria") {
                    if expenseChartData.isEmpty {
                        Text("Sem despesas no período selecionado.")
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        Chart(expenseChartData) { row in
                            BarMark(
                                x: .value("Categoria", row.category.rawValue),
                                y: .value("Valor", row.amount)
                            )
                            .foregroundStyle(AppTheme.brandBrown.gradient)
                        }
                        .frame(height: 240)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Fluxo Financeiro")
        .brandPlainBackground()
    }
}

