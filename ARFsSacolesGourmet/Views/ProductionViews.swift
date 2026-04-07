import SwiftUI
import SwiftData

struct ProductionView: View {
    @Query(sort: \ProductionBatch.productionDate, order: .reverse) private var batches: [ProductionBatch]
    @State private var showingForm = false

    var body: some View {
        List {
            Section("Histórico de Produções") {
                if batches.isEmpty {
                    Text("Nenhum lote de produção foi registrado ainda.")
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ForEach(batches, id: \.id) { batch in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(batch.flavor?.name ?? "Sabor removido")
                                    .font(.headline)
                                Spacer()
                                Text(batch.productionDate.brDate)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Text("Quantidade produzida: \(batch.quantityProduced)")
                                .font(.subheadline)
                            Text("Custo total: \(batch.totalCost.brlCurrency) | Custo unitário: \(batch.unitCost.brlCurrency)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                            if !batch.notes.isEmpty {
                                Text(batch.notes)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(AppTheme.cardBackground)
                }
            }
        }
        .navigationTitle("Produção")
        .listStyle(.insetGrouped)
        .brandScrollBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingForm = true
                } label: {
                    Label("Novo lote", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            NavigationStack {
                ProductionFormView()
            }
        }
    }
}

struct ProductionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Flavor.name) private var flavors: [Flavor]
    @Query(sort: \Recipe.updatedAt, order: .reverse) private var recipes: [Recipe]

    @StateObject private var viewModel = ProductionDraftViewModel()
    @State private var errorMessage = ""

    private var availableRecipes: [Recipe] {
        recipes.filter { recipe in
            guard let flavorID = viewModel.flavorID else { return false }
            return recipe.flavor?.id == flavorID
        }
    }

    var body: some View {
        Form {
            Section("Dados do lote") {
                Picker("Sabor", selection: $viewModel.flavorID) {
                    Text("Selecione").tag(UUID?.none)
                    ForEach(flavors.filter { $0.isActive }, id: \.id) { flavor in
                        Text(flavor.name).tag(Optional(flavor.id))
                    }
                }
                .onChange(of: viewModel.flavorID) { _, newValue in
                    if let flavor = flavors.first(where: { $0.id == newValue }) {
                        viewModel.recipeID = flavor.defaultRecipe?.id
                    }
                }

                Picker("Ficha técnica", selection: $viewModel.recipeID) {
                    Text("Selecione").tag(UUID?.none)
                    ForEach(availableRecipes, id: \.id) { recipe in
                        Text(recipe.title).tag(Optional(recipe.id))
                    }
                }

                Stepper("Quantidade produzida: \(viewModel.quantityProduced)", value: $viewModel.quantityProduced, in: 1...1_000)
                DatePicker("Data da produção", selection: $viewModel.productionDate, displayedComponents: .date)
                TextField("Observações", text: $viewModel.notes, axis: .vertical)
            }

            Section("Prévia de custo") {
                LabeledContent("Custo estimado do lote", value: viewModel.estimatedTotalCost(recipes: recipes).brlCurrency)
                if let recipeID = viewModel.recipeID,
                   let recipe = recipes.first(where: { $0.id == recipeID }) {
                    LabeledContent("Custo unitário estimado", value: recipe.yieldQuantity > 0 ? (viewModel.estimatedTotalCost(recipes: recipes) / Double(viewModel.quantityProduced)).brlCurrency : "R$ 0,00")
                    Text("Rendimento da ficha: \(recipe.yieldQuantity) unidades")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(AppTheme.danger)
                }
            }
        }
        .navigationTitle("Novo Lote")
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
            guard let flavorID = viewModel.flavorID,
                  let recipeID = viewModel.recipeID,
                  let flavor = flavors.first(where: { $0.id == flavorID }),
                  let recipe = recipes.first(where: { $0.id == recipeID }) else {
                throw BusinessError.invalidData("Selecione sabor e ficha técnica.")
            }

            _ = try ProductionService.createBatch(
                flavor: flavor,
                recipe: recipe,
                quantityProduced: viewModel.quantityProduced,
                date: viewModel.productionDate,
                notes: viewModel.notes,
                context: modelContext
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

