import SwiftUI
import SwiftData

struct CustomersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Customer.name) private var customers: [Customer]

    @State private var searchText = ""
    @State private var showingForm = false
    @State private var editingCustomer: Customer?

    private var filteredCustomers: [Customer] {
        customers.filter { customer in
            searchText.isEmpty || customer.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            Section("Clientes") {
                ForEach(filteredCustomers, id: \.id) { customer in
                    NavigationLink(destination: CustomerDetailView(customer: customer)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(customer.name)
                                    .font(.headline)
                                Spacer()
                                StatusPill(text: customer.isActive ? "Ativo" : "Inativo", color: customer.isActive ? AppTheme.success : AppTheme.textSecondary)
                            }
                            Text(customer.phone.isEmpty ? "Sem telefone cadastrado" : customer.phone)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                            Text("Total comprado: \(customer.totalBought.brlCurrency) | Em aberto: \(customer.openBalance.brlCurrency)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(AppTheme.cardBackground)
                    .swipeActions {
                        Button("Editar") {
                            editingCustomer = customer
                            showingForm = true
                        }
                        .tint(AppTheme.accent)

                        Button("Excluir", role: .destructive) {
                            modelContext.delete(customer)
                            try? modelContext.saveChanges()
                        }
                    }
                }
            }
        }
        .navigationTitle("Clientes")
        .searchable(text: $searchText, prompt: "Buscar cliente")
        .listStyle(.insetGrouped)
        .brandScrollBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingCustomer = nil
                    showingForm = true
                } label: {
                    Label("Novo cliente", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            NavigationStack {
                CustomerFormView(customer: editingCustomer)
            }
        }
    }
}

struct CustomerDetailView: View {
    let customer: Customer

    var body: some View {
        List {
            Section("Resumo") {
                LabeledContent("Telefone", value: customer.phone.isEmpty ? "Não informado" : customer.phone)
                LabeledContent("Instagram / Rede", value: customer.socialHandle.isEmpty ? "Não informado" : customer.socialHandle)
                LabeledContent("Endereço", value: customer.address.isEmpty ? "Não informado" : customer.address)
                LabeledContent("Bairro", value: customer.neighborhood.isEmpty ? "Não informado" : customer.neighborhood)
                LabeledContent("Total já comprado", value: customer.totalBought.brlCurrency)
                LabeledContent("Total em aberto", value: customer.openBalance.brlCurrency)
            }

            Section("Observações") {
                Text(customer.notes.isEmpty ? "Sem observações." : customer.notes)
                    .foregroundStyle(customer.notes.isEmpty ? AppTheme.textSecondary : AppTheme.textPrimary)
            }

            Section("Histórico de compras") {
                if customer.sales.isEmpty {
                    Text("Este cliente ainda não possui vendas registradas.")
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ForEach(customer.sales.sorted { $0.saleDate > $1.saleDate }, id: \.id) { sale in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(sale.saleDate.brDate)
                                    .font(.headline)
                                Spacer()
                                Text(sale.totalAmount.brlCurrency)
                                    .font(.headline)
                            }
                            Text("\(sale.paymentStatusLabel) • \(sale.origin.rawValue)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(customer.name)
        .listStyle(.insetGrouped)
        .brandScrollBackground()
    }
}

struct CustomerFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let customer: Customer?

    @State private var name: String
    @State private var phone: String
    @State private var socialHandle: String
    @State private var address: String
    @State private var neighborhood: String
    @State private var notes: String
    @State private var isActive: Bool

    init(customer: Customer?) {
        self.customer = customer
        _name = State(initialValue: customer?.name ?? "")
        _phone = State(initialValue: customer?.phone ?? "")
        _socialHandle = State(initialValue: customer?.socialHandle ?? "")
        _address = State(initialValue: customer?.address ?? "")
        _neighborhood = State(initialValue: customer?.neighborhood ?? "")
        _notes = State(initialValue: customer?.notes ?? "")
        _isActive = State(initialValue: customer?.isActive ?? true)
    }

    var body: some View {
        Form {
            Section("Dados do cliente") {
                TextField("Nome", text: $name)
                TextField("Telefone / WhatsApp", text: $phone)
                    .keyboardType(.phonePad)
                TextField("Instagram ou rede social", text: $socialHandle)
                TextField("Endereço", text: $address)
                TextField("Bairro", text: $neighborhood)
                Toggle("Ativo", isOn: $isActive)
                TextField("Observações", text: $notes, axis: .vertical)
            }
        }
        .navigationTitle(customer == nil ? "Novo Cliente" : "Editar Cliente")
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
        let model = customer ?? Customer(name: name)
        model.name = name
        model.phone = phone
        model.socialHandle = socialHandle
        model.address = address
        model.neighborhood = neighborhood
        model.notes = notes
        model.isActive = isActive
        model.updatedAt = .now
        if customer == nil {
            modelContext.insert(model)
        }
        try? modelContext.saveChanges()
        dismiss()
    }
}

