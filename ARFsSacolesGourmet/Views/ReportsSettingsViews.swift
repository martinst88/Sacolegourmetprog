import SwiftUI
import SwiftData
import Charts
import UniformTypeIdentifiers

struct ReportsView: View {
    @Query(sort: \Sale.saleDate, order: .reverse) private var sales: [Sale]
    @Query(sort: \PaymentRecord.paymentDate, order: .reverse) private var payments: [PaymentRecord]
    @Query(sort: \Expense.launchDate, order: .reverse) private var expenses: [Expense]
    @Query(sort: \Flavor.name) private var flavors: [Flavor]
    @Query(sort: \Receivable.dueDate) private var receivables: [Receivable]
    @Query(sort: \ProductionBatch.productionDate, order: .reverse) private var batches: [ProductionBatch]

    @StateObject private var viewModel = ReportsViewModel()
    @State private var csvDocument = TextExportDocument(text: "")
    @State private var showingSalesExport = false
    @State private var showingFinanceExport = false

    private var range: ClosedRange<Date> {
        viewModel.range()
    }

    private var salesByFlavor: [FlavorSalesSummary] {
        FinanceService.salesByFlavor(sales: sales, range: range)
    }

    private var clients: [ClientRevenueSummary] {
        FinanceService.clientRevenue(sales: sales, range: range)
    }

    private var expenseSummary: [ExpenseCategorySummary] {
        FinanceService.expensesByCategory(expenses: expenses, range: range)
    }

    private var filteredBatches: [ProductionBatch] {
        batches.filter { range.contains($0.productionDate) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PremiumCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Relatórios Gerenciais")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("Veja vendas, clientes, despesas, produção e exportações em uma leitura rápida e elegante.")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                PremiumCard(title: "Período do Relatório") {
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

                PremiumCard(title: "Sabores Mais Vendidos") {
                    if salesByFlavor.isEmpty {
                        Text("Sem vendas no período.")
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        Chart(salesByFlavor.prefix(5)) { row in
                            BarMark(
                                x: .value("Sabor", row.name),
                                y: .value("Quantidade", row.quantity)
                            )
                            .foregroundStyle(AppTheme.accent.gradient)
                        }
                        .frame(height: 240)
                    }
                }

                PremiumCard(title: "Faturamento por Cliente") {
                    if clients.isEmpty {
                        Text("Sem clientes com faturamento no período.")
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        ForEach(clients.prefix(6)) { client in
                            HStack {
                                Text(client.customerName)
                                Spacer()
                                Text(client.amount.brlCurrency)
                                    .font(.headline)
                            }
                            if client.id != clients.prefix(6).last?.id {
                                Divider()
                            }
                        }
                    }
                }

                PremiumCard(title: "Despesas por Categoria") {
                    if expenseSummary.isEmpty {
                        Text("Sem despesas no período.")
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        ForEach(expenseSummary) { row in
                            HStack {
                                Text(row.category.rawValue)
                                Spacer()
                                Text(row.amount.brlCurrency)
                                    .font(.headline)
                            }
                            if row.id != expenseSummary.last?.id {
                                Divider()
                            }
                        }
                    }
                }

                PremiumCard(title: "Indicadores Rápidos") {
                    let profit = viewModel.financeSummary(sales: sales, payments: payments, expenses: expenses)
                    VStack(alignment: .leading, spacing: 10) {
                        reportLine(title: "Lucro total do período", value: profit.netProfit.brlCurrency)
                        reportLine(title: "CPV do período", value: profit.costOfGoodsSold.brlCurrency)
                        reportLine(title: "Clientes com pagamento pendente", value: "\(receivables.filter { $0.balance > 0 }.count)")
                        reportLine(title: "Sabores em estoque baixo", value: "\(flavors.filter { $0.isLowStock }.count)")
                    }
                }

                PremiumCard(title: "Custo de Produção por Lote") {
                    if filteredBatches.isEmpty {
                        Text("Nenhum lote no período selecionado.")
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        ForEach(filteredBatches.prefix(6), id: \.id) { batch in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(batch.flavor?.name ?? "Sabor removido")
                                    Text(batch.productionDate.brDate)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(batch.totalCost.brlCurrency)
                                    Text("\(batch.unitCost.brlCurrency) / un.")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                            if batch.id != filteredBatches.prefix(6).last?.id {
                                Divider()
                            }
                        }
                    }
                }

                PremiumCard(title: "Exportação CSV") {
                    Button("Exportar vendas em CSV") {
                        csvDocument = viewModel.salesCSVDocument(sales: sales)
                        showingSalesExport = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)

                    Button("Exportar resumo financeiro em CSV") {
                        csvDocument = viewModel.financeCSVDocument(sales: sales, payments: payments, expenses: expenses)
                        showingFinanceExport = true
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.brandBrown)
                }
            }
            .padding(20)
        }
        .navigationTitle("Relatórios")
        .brandPlainBackground()
        .fileExporter(
            isPresented: $showingSalesExport,
            document: csvDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "relatorio-vendas"
        ) { _ in }
        .fileExporter(
            isPresented: $showingFinanceExport,
            document: csvDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "relatorio-financeiro"
        ) { _ in }
    }

    private func reportLine(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.headline)
        }
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage("arf_requires_local_pin") private var requiresPIN = false
    @AppStorage("arf_local_pin") private var localPIN = ""

    @State private var backupDocument = BackupDocument(data: Data())
    @State private var showingBackupExport = false
    @State private var showingBackupImport = false
    @State private var importMessage = ""

    var body: some View {
        List {
            Section("Acesso Local") {
                Toggle("Exigir PIN local", isOn: $requiresPIN)
                if requiresPIN {
                    SecureField("PIN", text: $localPIN)
                        .keyboardType(.numberPad)
                }
            }

            Section("Backup e Importação") {
                Button("Exportar backup JSON") {
                    if let data = try? BackupService.exportBackup(context: modelContext) {
                        backupDocument = BackupDocument(data: data)
                        showingBackupExport = true
                    }
                }

                Button("Importar backup JSON") {
                    showingBackupImport = true
                }

                if !importMessage.isEmpty {
                    Text(importMessage)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Section("Aplicativo") {
                Text("Versão inicial com funcionamento offline, persistência local em SwiftData e estrutura pronta para crescimento.")
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Compatível com futura exportação CSV/PDF e estratégias de backup mais avançadas.")
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .navigationTitle("Configurações")
        .listStyle(.insetGrouped)
        .brandScrollBackground()
        .fileExporter(
            isPresented: $showingBackupExport,
            document: backupDocument,
            contentType: .json,
            defaultFilename: "arfs-sacoles-backup"
        ) { _ in }
        .fileImporter(isPresented: $showingBackupImport, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                guard url.startAccessingSecurityScopedResource() else {
                    importMessage = "Não foi possível acessar o arquivo selecionado."
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                let data = try Data(contentsOf: url)
                try BackupService.importBackup(data: data, context: modelContext)
                importMessage = "Backup importado com sucesso."
            } catch {
                importMessage = "Falha ao importar backup: \(error.localizedDescription)"
            }
        }
    }
}

