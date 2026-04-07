import SwiftUI
import SwiftData

private enum FlavorFilterOption: String, CaseIterable, Identifiable {
    case all = "Todos"
    case active = "Ativos"
    case inactive = "Inativos"
    case lowStock = "Estoque Baixo"

    var id: String { rawValue }
}

private struct RecipeIngredientDraft: Identifiable {
    let id = UUID()
    var supplyID: UUID?
    var quantityUsed: Double = 0
    var usageUnit: UnitOfMeasure = .gram
    var notes: String = ""
}

struct OperationsHomeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PremiumCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Operação do Dia")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("Organize sabores, insumos e produção usando a mesma identidade elegante da marca e mantendo os custos sob controle.")
                            .foregroundStyle(AppTheme.textSecondary)

                        HStack(spacing: 10) {
                            StatusPill(text: "Sabores", color: AppTheme.accent)
                            StatusPill(text: "Insumos", color: AppTheme.brandBrown)
                            StatusPill(text: "Produção", color: AppTheme.highlight)
                        }
                    }
                }

                NavigationLink(destination: FlavorsListView()) {
                    ModuleTile(
                        title: "Sabores",
                        subtitle: "Cadastro, margem, estoque mínimo e fichas técnicas.",
                        systemImage: "popcorn.fill",
                        tint: AppTheme.accent
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: SuppliesListView()) {
                    ModuleTile(
                        title: "Insumos e Materiais",
                        subtitle: "Entradas, saídas, ajustes de inventário e histórico.",
                        systemImage: "shippingbox.fill",
                        tint: AppTheme.brandBrown
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: ProductionView()) {
                    ModuleTile(
                        title: "Produção",
                        subtitle: "Registre lotes com baixa automática de insumos.",
                        systemImage: "fork.knife.circle.fill",
                        tint: AppTheme.highlight
                    )
                }
                .buttonStyle(.plain)

                PremiumCard(title: "Acompanhamento") {
                    Text("Use este módulo para manter estoque, receitas e produção sempre alinhados com a operação real do negócio.")
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(20)
        }
        .navigationTitle("Operação")
        .brandPlainBackground()
    }
}

struct FlavorsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Flavor.name) private var flavors: [Flavor]

    @State private var searchText = ""
    @State private var filter: FlavorFilterOption = .all
    @State private var showingForm = false
    @State private var editingFlavor: Flavor?

    private var filteredFlavors: [Flavor] {
        flavors.filter { flavor in
            let matchesSearch = searchText.isEmpty || flavor.name.localizedCaseInsensitiveContains(searchText)
            let matchesFilter: Bool
            switch filter {
            case .all:
                matchesFilter = true
            case .active:
                matchesFilter = flavor.isActive
            case .inactive:
                matchesFilter = !flavor.isActive
            case .lowStock:
                matchesFilter = flavor.isLowStock
            }
            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Filtro", selection: $filter) {
                    ForEach(FlavorFilterOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }

            Section("Sabores Cadastrados") {
                ForEach(filteredFlavors, id: \.id) { flavor in
                    NavigationLink(destination: FlavorDetailView(flavor: flavor)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(flavor.name)
                                    .font(.headline)
                                Spacer()
                                if !flavor.isActive {
                                    StatusPill(text: "Inativo", color: AppTheme.textSecondary)
                                } else if flavor.isLowStock {
                                    StatusPill(text: "Estoque baixo", color: AppTheme.warning)
                                }
                            }

                            Text(flavor.flavorDescription)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)

                            HStack {
                                Text("Venda: \(flavor.salePrice.brlCurrency)")
                                Text("Custo: \(flavor.estimatedUnitCost.brlCurrency)")
                                Text("Estoque: \(flavor.stockQuantity.brInteger)")
                            }
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(AppTheme.cardBackground)
                    .swipeActions(edge: .trailing) {
                        Button("Editar") {
                            editingFlavor = flavor
                            showingForm = true
                        }
                        .tint(AppTheme.accent)

                        Button("Excluir", role: .destructive) {
                            modelContext.delete(flavor)
                            try? modelContext.saveChanges()
                        }
                    }
                }
            }
        }
        .navigationTitle("Sabores")
        .searchable(text: $searchText, prompt: "Buscar sabor")
        .listStyle(.insetGrouped)
        .brandScrollBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingFlavor = nil
                    showingForm = true
                } label: {
                    Label("Novo sabor", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            NavigationStack {
                FlavorFormView(flavor: editingFlavor)
            }
        }
    }
}

struct FlavorDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let flavor: Flavor

    @State private var showingRecipeForm = false
    @State private var editingRecipe: Recipe?

    var body: some View {
        List {
            Section("Informações") {
                LabeledContent("Descrição", value: flavor.flavorDescription.isEmpty ? "Sem descrição" : flavor.flavorDescription)
                LabeledContent("Preço de venda", value: flavor.salePrice.brlCurrency)
                LabeledContent("Custo estimado", value: flavor.estimatedUnitCost.brlCurrency)
                LabeledContent("Margem estimada", value: "\(Int(flavor.estimatedMarginPercent * 100))%")
                LabeledContent("Estoque", value: "\(flavor.stockQuantity)")
                LabeledContent("Estoque mínimo", value: "\(flavor.minimumStock)")
                LabeledContent("Status", value: flavor.isActive ? "Ativo" : "Inativo")
            }

            Section("Fichas Técnicas") {
                if flavor.recipes.isEmpty {
                    Text("Ainda não há ficha técnica cadastrada para este sabor.")
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ForEach(flavor.recipes.sorted { $0.createdAt > $1.createdAt }, id: \.id) { recipe in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(recipe.title)
                                    .font(.headline)
                                Spacer()
                                if recipe.isDefault {
                                    StatusPill(text: "Padrão", color: AppTheme.success)
                                }
                            }

                            Text("Rendimento: \(recipe.yieldQuantity) unidades")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)

                            Text("Custo total: \(RecipeCostService.totalCost(for: recipe).brlCurrency) | Unitário: \(RecipeCostService.costPerUnit(for: recipe).brlCurrency)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)

                            ForEach(recipe.ingredients.sorted { ($0.supplyItem?.name ?? "") < ($1.supplyItem?.name ?? "") }, id: \.id) { ingredient in
                                Text("• \((ingredient.supplyItem?.name ?? "Sem insumo")): \(Formatters.decimal.string(from: NSNumber(value: ingredient.quantityUsed)) ?? "0") \(ingredient.usageUnit.label)")
                                    .font(.caption)
                            }

                            HStack {
                                Button("Editar") {
                                    editingRecipe = recipe
                                    showingRecipeForm = true
                                }
                                Button("Tornar padrão") {
                                    flavor.recipes.forEach { $0.isDefault = false }
                                    recipe.isDefault = true
                                    flavor.estimatedUnitCost = RecipeCostService.costPerUnit(for: recipe)
                                    try? modelContext.saveChanges()
                                }
                            }
                            .buttonStyle(.borderless)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                        }
                        .padding(.vertical, 6)
                    }
                    .onDelete { offsets in
                        let items = flavor.recipes.sorted { $0.createdAt > $1.createdAt }
                        offsets.map { items[$0] }.forEach(modelContext.delete)
                        try? modelContext.saveChanges()
                    }
                }
            }
        }
        .navigationTitle(flavor.name)
        .listStyle(.insetGrouped)
        .brandScrollBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingRecipe = nil
                    showingRecipeForm = true
                } label: {
                    Label("Nova ficha", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingRecipeForm) {
            NavigationStack {
                RecipeFormView(flavor: flavor, recipe: editingRecipe)
            }
        }
    }
}

struct FlavorFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let flavor: Flavor?

    @State private var name: String
    @State private var flavorDescription: String
    @State private var salePrice: Double
    @State private var estimatedUnitCost: Double
    @State private var stockQuantity: Int
    @State private var minimumStock: Int
    @State private var isActive: Bool
    @State private var notes: String

    init(flavor: Flavor?) {
        self.flavor = flavor
        _name = State(initialValue: flavor?.name ?? "")
        _flavorDescription = State(initialValue: flavor?.flavorDescription ?? "")
        _salePrice = State(initialValue: flavor?.salePrice ?? 0)
        _estimatedUnitCost = State(initialValue: flavor?.estimatedUnitCost ?? 0)
        _stockQuantity = State(initialValue: flavor?.stockQuantity ?? 0)
        _minimumStock = State(initialValue: flavor?.minimumStock ?? 10)
        _isActive = State(initialValue: flavor?.isActive ?? true)
        _notes = State(initialValue: flavor?.notes ?? "")
    }

    var body: some View {
        Form {
            Section("Dados do sabor") {
                TextField("Nome do sabor", text: $name)
                TextField("Descrição", text: $flavorDescription, axis: .vertical)
                TextField("Preço de venda", value: $salePrice, formatter: Formatters.decimal)
                    .keyboardType(.decimalPad)
                TextField("Custo estimado manual", value: $estimatedUnitCost, formatter: Formatters.decimal)
                    .keyboardType(.decimalPad)
                Stepper("Estoque atual: \(stockQuantity)", value: $stockQuantity, in: 0...10_000)
                Stepper("Estoque mínimo: \(minimumStock)", value: $minimumStock, in: 0...10_000)
                Toggle("Ativo", isOn: $isActive)
                TextField("Observações", text: $notes, axis: .vertical)
            }
        }
        .navigationTitle(flavor == nil ? "Novo Sabor" : "Editar Sabor")
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
        let current = flavor ?? Flavor(name: name, salePrice: salePrice)
        current.name = name
        current.flavorDescription = flavorDescription
        current.salePrice = salePrice
        current.estimatedUnitCost = estimatedUnitCost
        current.stockQuantity = stockQuantity
        current.minimumStock = minimumStock
        current.isActive = isActive
        current.notes = notes
        current.updatedAt = .now
        if flavor == nil {
            modelContext.insert(current)
        }
        try? modelContext.saveChanges()
        dismiss()
    }
}

struct RecipeFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SupplyItem.name) private var supplies: [SupplyItem]

    let flavor: Flavor
    let recipe: Recipe?

    @State private var title: String
    @State private var yieldQuantity: Int
    @State private var notes: String
    @State private var isDefault: Bool
    @State private var ingredientDrafts: [RecipeIngredientDraft]

    init(flavor: Flavor, recipe: Recipe?) {
        self.flavor = flavor
        self.recipe = recipe
        _title = State(initialValue: recipe?.title ?? "Ficha Técnica \(flavor.name)")
        _yieldQuantity = State(initialValue: recipe?.yieldQuantity ?? 20)
        _notes = State(initialValue: recipe?.notes ?? "")
        _isDefault = State(initialValue: recipe?.isDefault ?? flavor.recipes.isEmpty)
        _ingredientDrafts = State(initialValue: recipe?.ingredients.map {
            RecipeIngredientDraft(supplyID: $0.supplyItem?.id, quantityUsed: $0.quantityUsed, usageUnit: $0.usageUnit, notes: $0.notes)
        } ?? [RecipeIngredientDraft()])
    }

    private var previewCost: Double {
        ingredientDrafts.reduce(0) { result, draft in
            guard let supplyID = draft.supplyID,
                  let supply = supplies.first(where: { $0.id == supplyID }),
                  draft.usageUnit.isCompatible(with: supply.unit) else {
                return result
            }
            let base = draft.usageUnit.toBase(draft.quantityUsed)
            let costPerBase = supply.purchaseCost / supply.unit.baseFactor
            return result + (base * costPerBase)
        }
    }

    var body: some View {
        Form {
            Section("Receita") {
                TextField("Nome da ficha técnica", text: $title)
                Stepper("Rendimento: \(yieldQuantity) sacolés", value: $yieldQuantity, in: 1...500)
                Toggle("Definir como padrão do sabor", isOn: $isDefault)
                TextField("Observações", text: $notes, axis: .vertical)
            }

            Section("Ingredientes") {
                ForEach($ingredientDrafts) { $draft in
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Insumo", selection: $draft.supplyID) {
                            Text("Selecione").tag(UUID?.none)
                            ForEach(supplies.filter { $0.isActive }, id: \.id) { supply in
                                Text(supply.name).tag(Optional(supply.id))
                            }
                        }

                        TextField("Quantidade usada", value: $draft.quantityUsed, formatter: Formatters.decimal)
                            .keyboardType(.decimalPad)

                        Picker("Unidade", selection: $draft.usageUnit) {
                            ForEach(compatibleUnits(for: draft.supplyID)) { unit in
                                Text(unit.label).tag(unit)
                            }
                        }

                        TextField("Observação do ingrediente", text: $draft.notes)
                    }
                }
                .onDelete { ingredientDrafts.remove(atOffsets: $0) }

                Button("Adicionar ingrediente") {
                    ingredientDrafts.append(RecipeIngredientDraft())
                }
            }

            Section("Custo calculado") {
                LabeledContent("Custo total", value: previewCost.brlCurrency)
                LabeledContent("Custo por unidade", value: yieldQuantity > 0 ? (previewCost / Double(yieldQuantity)).brlCurrency : "R$ 0,00")
            }
        }
        .navigationTitle(recipe == nil ? "Nova Ficha" : "Editar Ficha")
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

    private func compatibleUnits(for supplyID: UUID?) -> [UnitOfMeasure] {
        guard let supplyID,
              let supply = supplies.first(where: { $0.id == supplyID }) else {
            return UnitOfMeasure.allCases
        }
        return UnitOfMeasure.allCases.filter { $0.isCompatible(with: supply.unit) }
    }

    private func save() {
        let model = recipe ?? Recipe(title: title, yieldQuantity: yieldQuantity, flavor: flavor)
        model.title = title
        model.yieldQuantity = yieldQuantity
        model.notes = notes
        model.isDefault = isDefault
        model.updatedAt = .now
        model.flavor = flavor

        if recipe == nil {
            modelContext.insert(model)
        } else {
            recipe?.ingredients.forEach(modelContext.delete)
        }

        if isDefault {
            flavor.recipes.forEach { $0.isDefault = false }
            model.isDefault = true
        }

        ingredientDrafts.forEach { draft in
            guard let supplyID = draft.supplyID,
                  let supply = supplies.first(where: { $0.id == supplyID }) else {
                return
            }
            let ingredient = RecipeIngredient(
                quantityUsed: draft.quantityUsed,
                usageUnit: draft.usageUnit,
                notes: draft.notes,
                recipe: model,
                supplyItem: supply
            )
            modelContext.insert(ingredient)
        }

        flavor.estimatedUnitCost = RecipeCostService.costPerUnit(for: model)
        flavor.updatedAt = .now
        try? modelContext.saveChanges()
        dismiss()
    }
}

