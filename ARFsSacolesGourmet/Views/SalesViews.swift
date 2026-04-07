import SwiftUI
import SwiftData

private enum ReceivableFilterOption: String, CaseIterable, Identifiable {
    case all = "Todos"
    case pending = "Pendentes"
    case overdue = "Vencidos"
    case paid = "Pagos"

    var id: String { rawValue }
}

struct SalesHomeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PremiumCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Vendas e Pedidos")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("Catálogo, venda manual, histórico e cobrança reunidos em um fluxo simples para o dia a dia.")
                            .foregroundStyle(AppTheme.textSecondary)

                        HStack(spacing: 10) {
                            StatusPill(text: "Catálogo", color: AppTheme.accent)
                            StatusPill(text: "WhatsApp", color: AppTheme.success)
                            StatusPill(text: "Recebimentos", color: AppTheme.brandBrown)
                        }
                    }
                }

                NavigationLink(destination: CatalogView()) {
                    ModuleTile(
                        title: "Catálogo para Pedidos",
                        subtitle: "Mostre sabores disponíveis, preço e estoque.",
                        systemImage: "menucard.fill",
                        tint: AppTheme.accent
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: NewSaleView(defaultOrigin: .manual)) {
                    ModuleTile(
                        title: "Nova Venda",
                        subtitle: "Registre venda manual, baixa estoque e controla saldo.",
                        systemImage: "cart.badge.plus",
                        tint: AppTheme.highlight
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: SalesHistoryView()) {
                    ModuleTile(
                        title: "Histórico de Vendas",
                        subtitle: "Acompanhe vendas recentes e detalhes de pagamento.",
                        systemImage: "clock.arrow.circlepath",
                        tint: AppTheme.brandBrown
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: CustomersView()) {
                    ModuleTile(
                        title: "Clientes",
                        subtitle: "Cadastro completo e visão do histórico de compras.",
                        systemImage: "person.2.fill",
                        tint: AppTheme.success
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: ReceivablesView()) {
                    ModuleTile(
                        title: "Contas a Receber",
                        subtitle: "Pendências, vencimentos e recebimentos parciais.",
                        systemImage: "wallet.pass.fill",
                        tint: AppTheme.warning
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .navigationTitle("Vendas")
        .brandPlainBackground()
    }
}

struct CatalogView: View {
    @Query(sort: \Flavor.name) private var flavors: [Flavor]
    @State private var searchText = ""

    private var availableFlavors: [Flavor] {
        flavors.filter { $0.isActive && (searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)) }
    }

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PremiumCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Catálogo da Marca")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("Use este catálogo para registrar pedidos já com os sabores disponíveis e o preço correto.")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(availableFlavors, id: \.id) { flavor in
                        PremiumCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top) {
                                    Text(flavor.name)
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    if flavor.isLowStock {
                                        StatusPill(text: "Baixo", color: AppTheme.warning)
                                    }
                                }

                                Text(flavor.flavorDescription.isEmpty ? "Sem descrição cadastrada." : flavor.flavorDescription)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineLimit(3)

                                Spacer(minLength: 0)

                                Text(flavor.salePrice.brlCurrency)
                                    .font(.title3.bold())
                                    .foregroundStyle(AppTheme.accent)

                                Text("Estoque: \(flavor.stockQuantity)")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
                        }
                    }
                }

                NavigationLink(destination: NewSaleView(defaultOrigin: .catalog)) {
                    PremiumCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Registrar pedido pelo catálogo")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("Ao salvar, o app pode abrir o WhatsApp com a mensagem pronta para envio ao cliente.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "message.fill")
                                .font(.title3)
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .navigationTitle("Catálogo")
        .searchable(text: $searchText, prompt: "Buscar sabor")
        .brandPlainBackground()
    }
}

struct NewSaleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @Query(sort: \Customer.name) private var customers: [Customer]
    @Query(sort: \Flavor.name) private var flavors: [Flavor]

    @StateObject private var viewModel = SaleComposerViewModel()
    @State private var errorMessage = ""

    let defaultOrigin: SaleOrigin

    init(defaultOrigin: SaleOrigin) {
        self.defaultOrigin = defaultOrigin
    }

    private var subtotal: Double {
        viewModel.subtotal(using: flavors)
    }

    private var total: Double {
        viewModel.total(using: flavors)
    }

    private var openBalance: Double {
        max(total - viewModel.amountReceivedNow, 0)
    }

    var body: some View {
        Form {
            Section("Cliente") {
                Toggle("Cliente avulso", isOn: $viewModel.isWalkIn)
                if !viewModel.isWalkIn {
                    Picker("Cliente", selection: $viewModel.customerID) {
                        Text("Selecione").tag(UUID?.none)
                        ForEach(customers.filter { $0.isActive }, id: \.id) { customer in
                            Text(customer.name).tag(Optional(customer.id))
                        }
                    }
                }
                Picker("Origem", selection: $viewModel.origin) {
                    ForEach(SaleOrigin.allCases) { origin in
                        Text(origin.rawValue).tag(origin)
                    }
                }
            }

            Section("Itens da venda") {
                ForEach($viewModel.lines) { $line in
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Sabor", selection: $line.flavorID) {
                            Text("Selecione").tag(UUID?.none)
                            ForEach(flavors.filter { $0.isActive }, id: \.id) { flavor in
                                Text("\(flavor.name) (\(flavor.stockQuantity))").tag(Optional(flavor.id))
                            }
                        }
                        .onChange(of: line.flavorID) { _, _ in
                            viewModel.syncPrice(for: line.id, flavors: flavors)
                        }

                        Stepper("Quantidade: \(line.quantity)", value: $line.quantity, in: 1...500)

                        TextField("Preço unitário", value: $line.unitPrice, formatter: Formatters.decimal)
                            .keyboardType(.decimalPad)
                    }
                }
                .onDelete(perform: viewModel.removeLine)

                Button("Adicionar item") {
                    viewModel.addLine()
                }
                .foregroundStyle(AppTheme.accent)
            }

            Section("Pagamento") {
                Picker("Forma de pagamento", selection: $viewModel.paymentMethod) {
                    ForEach(PaymentMethod.allCases) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                TextField("Desconto", value: $viewModel.discount, formatter: Formatters.decimal)
                    .keyboardType(.decimalPad)
                TextField("Valor recebido agora", value: $viewModel.amountReceivedNow, formatter: Formatters.decimal)
                    .keyboardType(.decimalPad)
                DatePicker("Data da venda", selection: $viewModel.saleDate, displayedComponents: .date)
                DatePicker("Vencimento do saldo", selection: $viewModel.dueDate, displayedComponents: .date)
                Toggle("Abrir WhatsApp após salvar", isOn: $viewModel.autoOpenWhatsApp)
                TextField("Observações", text: $viewModel.notes, axis: .vertical)
            }

            Section("Resumo") {
                LabeledContent("Subtotal", value: subtotal.brlCurrency)
                LabeledContent("Total", value: total.brlCurrency)
                LabeledContent("Saldo em aberto", value: openBalance.brlCurrency)
            }

            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(AppTheme.danger)
                }
            }
        }
        .navigationTitle("Nova Venda")
        .brandScrollBackground()
        .onAppear {
            viewModel.reset(origin: defaultOrigin)
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") { save() }
            }
        }
    }

    private func save() {
        do {
            let input = try viewModel.buildInput(customers: customers, flavors: flavors)
            let sale = try SalesService.createSale(input: input, context: modelContext)

            if viewModel.autoOpenWhatsApp, !viewModel.isWalkIn, sale.customer != nil, let url = try? WhatsAppMessageBuilder.url(for: sale) {
                openURL(url)
            }

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SalesHistoryView: View {
    @Query(sort: \Sale.saleDate, order: .reverse) private var sales: [Sale]
    @State private var searchText = ""

    private var filteredSales: [Sale] {
        sales.filter { searchText.isEmpty || $0.customerNameSnapshot.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            Section("Vendas registradas") {
                ForEach(filteredSales, id: \.id) { sale in
                    NavigationLink(destination: SaleDetailView(sale: sale)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(sale.customerNameSnapshot)
                                    .font(.headline)
                                Spacer()
                                Text(sale.totalAmount.brlCurrency)
                                    .font(.headline)
                            }
                            Text("\(sale.saleDate.brDate) • \(sale.paymentStatusLabel) • \(sale.paymentMethod.rawValue)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(AppTheme.cardBackground)
                }
            }
        }
        .navigationTitle("Histórico")
        .searchable(text: $searchText, prompt: "Buscar cliente")
        .listStyle(.insetGrouped)
        .brandScrollBackground()
    }
}

struct SaleDetailView: View {
    @Environment(\.openURL) private var openURL
    let sale: Sale

    var body: some View {
        List {
            Section("Resumo da venda") {
                LabeledContent("Cliente", value: sale.customerNameSnapshot)
                LabeledContent("Data", value: sale.saleDate.brDate)
                LabeledContent("Origem", value: sale.origin.rawValue)
                LabeledContent("Forma de pagamento", value: sale.paymentMethod.rawValue)
                LabeledContent("Subtotal", value: sale.subtotalAmount.brlCurrency)
                LabeledContent("Desconto", value: sale.discountAmount.brlCurrency)
                LabeledContent("Total", value: sale.totalAmount.brlCurrency)
                LabeledContent("Recebido", value: sale.amountReceived.brlCurrency)
                LabeledContent("Em aberto", value: sale.amountOpen.brlCurrency)
                LabeledContent("Status", value: sale.paymentStatusLabel)
            }

            Section("Itens") {
                ForEach(sale.items.sorted { ($0.flavor?.name ?? "") < ($1.flavor?.name ?? "") }, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.flavor?.name ?? "Sabor removido")
                            Spacer()
                            Text(item.lineTotal.brlCurrency)
                        }
                        Text("\(item.quantity)x \(item.unitPrice.brlCurrency)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }

            Section("Recebimentos") {
                if sale.paymentRecords.isEmpty {
                    Text("Nenhum recebimento registrado.")
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ForEach(sale.paymentRecords.sorted { $0.paymentDate > $1.paymentDate }, id: \.id) { payment in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(payment.amount.brlCurrency)
                                Spacer()
                                Text(payment.paymentDate.brDate)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Text(payment.method.rawValue)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
            }

            if !sale.notes.isEmpty {
                Section("Observações") {
                    Text(sale.notes)
                }
            }

            if sale.customer != nil {
                Section {
                    Button("Abrir mensagem no WhatsApp") {
                        if let url = try? WhatsAppMessageBuilder.url(for: sale) {
                            openURL(url)
                        }
                    }
                    .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .navigationTitle("Detalhes da Venda")
        .listStyle(.insetGrouped)
        .brandScrollBackground()
    }
}

struct ReceivablesView: View {
    @Query(sort: \Receivable.dueDate) private var receivables: [Receivable]
    @State private var filter: ReceivableFilterOption = .all
    @State private var selectedReceivable: Receivable?

    private var filteredReceivables: [Receivable] {
        receivables.filter { receivable in
            switch filter {
            case .all:
                return true
            case .pending:
                return receivable.balance > 0 && receivable.dueDate >= .now.startOfDayInBrazil
            case .overdue:
                return receivable.balance > 0 && receivable.dueDate < .now.startOfDayInBrazil
            case .paid:
                return receivable.balance == 0
            }
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Filtro", selection: $filter) {
                    ForEach(ReceivableFilterOption.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }

            Section("Contas a receber") {
                ForEach(filteredReceivables, id: \.id) { receivable in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(receivable.customer?.name ?? receivable.sale?.customerNameSnapshot ?? "Cliente")
                                .font(.headline)
                            Spacer()
                            Text(receivable.balance.brlCurrency)
                                .font(.headline)
                        }
                        Text("Vencimento: \(receivable.dueDate.brDate) • \(receivable.statusLabel)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text("Total: \(receivable.totalAmount.brlCurrency) | Recebido: \(receivable.amountReceived.brlCurrency)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        if receivable.balance > 0 {
                            Button("Registrar recebimento") {
                                selectedReceivable = receivable
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(AppTheme.cardBackground)
                }
            }
        }
        .navigationTitle("Contas a Receber")
        .listStyle(.insetGrouped)
        .brandScrollBackground()
        .sheet(isPresented: Binding(get: { selectedReceivable != nil }, set: { if !$0 { selectedReceivable = nil } })) {
            if let selectedReceivable {
                NavigationStack {
                    ReceivePaymentFormView(receivable: selectedReceivable)
                }
            }
        }
    }
}

struct ReceivePaymentFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let receivable: Receivable

    @State private var amount = 0.0
    @State private var date = Date()
    @State private var method: PaymentMethod = .pix
    @State private var notes = ""
    @State private var errorMessage = ""

    var body: some View {
        Form {
            Section("Saldo atual") {
                LabeledContent("Cliente", value: receivable.customer?.name ?? receivable.sale?.customerNameSnapshot ?? "Cliente")
                LabeledContent("Saldo pendente", value: receivable.balance.brlCurrency)
            }

            Section("Recebimento") {
                TextField("Valor recebido", value: $amount, formatter: Formatters.decimal)
                    .keyboardType(.decimalPad)
                DatePicker("Data", selection: $date, displayedComponents: .date)
                Picker("Forma", selection: $method) {
                    ForEach(PaymentMethod.allCases.filter { $0 != .pending && $0 != .partial }) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                TextField("Observações", text: $notes, axis: .vertical)
            }

            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(AppTheme.danger)
                }
            }
        }
        .navigationTitle("Registrar Recebimento")
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
        do {
            try ReceivablesService.registerPayment(
                receivable: receivable,
                amount: amount,
                method: method,
                date: date,
                notes: notes,
                context: modelContext
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

