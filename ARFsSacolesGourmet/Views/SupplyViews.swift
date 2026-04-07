import SwiftUI
import SwiftData

private enum SupplyFilterOption: String, CaseIterable, Identifiable {
    case all = "Todos"
    case lowStock = "Estoque Baixo"
    case inactive = "Inativos"

    var id: String { rawValue }
}

struct SuppliesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SupplyItem.name) private var supplies: [SupplyItem]

    @State private var searchText = ""
    @State private var filter: SupplyFilterOption = .all
    @State private var showingForm = false
    @State private var editingSupply: SupplyItem?

    private var filteredSupplies: [SupplyItem] {
        supplies.filter { supply in
            let matchesSearch = searchText.isEmpty || supply.name.localizedCaseInsensitiveContains(searchText)
            let matchesFilter: Bool
            switch filter {
            case .all:
                matchesFilter = true
            case .lowStock:
                matchesFilter = supply.isLowStock
            case .inactive:
                matchesFilter = !supply.isActive
            }
            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Filtro", selection: $filter) {
                    ForEach(SupplyFilterOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }

            Section("Insumos e Materiais") {
                ForEach(filteredSupplies, id: \.id) { supply in
                    NavigationLink(destination: SupplyDetailView(supply: supply)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(supply.name)
                                    .font(.headline)
                                Spacer()
                                if supply.isLowStock {
                                    StatusPill(text: "Baixo", color: AppTheme.warning)
                                }
                            }
                            Text("\(supply.category.rawValue) • \(Formatters.decimal.string(from: NSNumber(value: supply.currentStock)) ?? "0") \(supply.unit.label)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                            Text("Custo de compra: \(supply.purchaseCost.brlCurrency) por \(supply.unit.label)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(AppTheme.cardBackground)
                    .swipeActions {
                        Button("Editar") {
                            editingSupply = supply
                            showingForm = true
                        }
                        .tint(AppTheme.accent)

                        Button("Excluir", role: .destructive) {
                            modelContext.delete(supply)
                            try? modelContext.saveChanges()
                        }
                    }
                }
            }
        }
        .navigationTitle("Insumos")
        .searchable(text: $searchText, prompt: "Buscar insumo")
        .listStyle(.insetGrouped)
        .brandScrollBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingSupply = nil
                    showingForm = true
                } label: {
                    Label("Novo insumo", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            NavigationStack {
                SupplyFormView(supply: editingSupply)
            }
        }
    }
}

struct SupplyDetailView: View {
    let supply: SupplyItem
    @State private var showingMovementForm = false
    @State private var showingEditForm = false

    var body: some View {
        List {
            Section("Resumo") {
                LabeledContent("Categoria", value: supply.category.rawValue)
                LabeledContent("Unidade", value: supply.unit.label)
                LabeledContent("Estoque atual", value: "\(Formatters.decimal.string(from: NSNumber(value: supply.currentStock)) ?? "0") \(supply.unit.label)")
                LabeledContent("Estoque mínimo", value: "\(Formatters.decimal.string(from: NSNumber(value: supply.minimumStock)) ?? "0") \(supply.unit.label)")
                LabeledContent("Fornecedor", value: supply.supplier.isEmpty ? "Não informado" : supply.supplier)
                LabeledContent("Última compra", value: supply.lastPurchaseDate?.brDate ?? "Sem registro")
                LabeledContent("Custo por unidade", value: supply.purchaseCost.brlCurrency)
            }

            Section("Observações") {
                Text(supply.notes.isEmpty ? "Sem observações cadastradas." : supply.notes)
                    .foregroundStyle(supply.notes.isEmpty ? AppTheme.textSecondary : AppTheme.textPrimary)
            }

            Section("Histórico de Movimentações") {
                if supply.movements.isEmpty {
                    Text("Ainda não há movimentações registradas.")
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ForEach(supply.movements.sorted { $0.movementDate > $1.movementDate }, id: \.id) { movement in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(movement.type.rawValue)
                                    .font(.headline)
                                Spacer()
                                Text(movement.movementDate.brDate)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Text("Qtd: \(Formatters.decimal.string(from: NSNumber(value: movement.quantity)) ?? "0") \(supply.unit.label)")
                                .font(.caption)
                            Text("De \(Formatters.decimal.string(from: NSNumber(value: movement.previousQuantity)) ?? "0") para \(Formatters.decimal.string(from: NSNumber(value: movement.newQuantity)) ?? "0")")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                            if !movement.notes.isEmpty {
                                Text(movement.notes)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(supply.name)
        .listStyle(.insetGrouped)
        .brandScrollBackground()
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Editar") { showingEditForm = true }
                Button("Movimentar") { showingMovementForm = true }
            }
        }
        .sheet(isPresented: $showingMovementForm) {
            NavigationStack {
                SupplyMovementFormView(supply: supply)
            }
        }
        .sheet(isPresented: $showingEditForm) {
            NavigationStack {
                SupplyFormView(supply: supply)
            }
        }
    }
}

struct SupplyFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let supply: SupplyItem?

    @State private var name: String
    @State private var category: SupplyCategory
    @State private var unit: UnitOfMeasure
    @State private var currentStock: Double
    @State private var minimumStock: Double
    @State private var purchaseCost: Double
    @State private var supplier: String
    @State private var lastPurchaseDate: Date
    @State private var notes: String
    @State private var isActive: Bool

    init(supply: SupplyItem?) {
        self.supply = supply
        _name = State(initialValue: supply?.name ?? "")
        _category = State(initialValue: supply?.category ?? .other)
        _unit = State(initialValue: supply?.unit ?? .unit)
        _currentStock = State(initialValue: supply?.currentStock ?? 0)
        _minimumStock = State(initialValue: supply?.minimumStock ?? 0)
        _purchaseCost = State(initialValue: supply?.purchaseCost ?? 0)
        _supplier = State(initialValue: supply?.supplier ?? "")
        _lastPurchaseDate = State(initialValue: supply?.lastPurchaseDate ?? .now)
        _notes = State(initialValue: supply?.notes ?? "")
        _isActive = State(initialValue: supply?.isActive ?? true)
    }

    var body: some View {
        Form {
            Section("Dados do insumo") {
                TextField("Nome", text: $name)
                Picker("Categoria", selection: $category) {
                    ForEach(SupplyCategory.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                Picker("Unidade", selection: $unit) {
                    ForEach(UnitOfMeasure.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                TextField("Estoque atual", value: $currentStock, formatter: Formatters.decimal)
                    .keyboardType(.decimalPad)
                TextField("Estoque mínimo", value: $minimumStock, formatter: Formatters.decimal)
                    .keyboardType(.decimalPad)
                TextField("Custo de compra", value: $purchaseCost, formatter: Formatters.decimal)
                    .keyboardType(.decimalPad)
                TextField("Fornecedor", text: $supplier)
                DatePicker("Última compra", selection: $lastPurchaseDate, displayedComponents: .date)
                Toggle("Ativo", isOn: $isActive)
                TextField("Observações", text: $notes, axis: .vertical)
            }
        }
        .navigationTitle(supply == nil ? "Novo Insumo" : "Editar Insumo")
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
        let model = supply ?? SupplyItem(name: name, category: category, unit: unit)
        model.name = name
        model.category = category
        model.unit = unit
        model.currentStock = currentStock
        model.minimumStock = minimumStock
        model.purchaseCost = purchaseCost
        model.supplier = supplier
        model.lastPurchaseDate = lastPurchaseDate
        model.notes = notes
        model.isActive = isActive
        model.updatedAt = .now
        if supply == nil {
            modelContext.insert(model)
        }
        try? modelContext.saveChanges()
        dismiss()
    }
}

struct SupplyMovementFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let supply: SupplyItem

    @State private var type: SupplyMovementType = .stockIn
    @State private var quantity = 0.0
    @State private var date = Date()
    @State private var note = ""
    @State private var errorMessage = ""

    var body: some View {
        Form {
            Section("Movimentação") {
                Picker("Tipo", selection: $type) {
                    ForEach([SupplyMovementType.stockIn, .stockOut, .adjustment]) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                TextField("Quantidade", value: $quantity, formatter: Formatters.decimal)
                    .keyboardType(.decimalPad)
                DatePicker("Data", selection: $date, displayedComponents: .date)
                TextField("Observação", text: $note, axis: .vertical)
            }

            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(AppTheme.danger)
                }
            }
        }
        .navigationTitle("Movimentar Estoque")
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
            try InventoryService.registerSupplyMovement(item: supply, type: type, quantity: quantity, date: date, note: note, context: modelContext)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

