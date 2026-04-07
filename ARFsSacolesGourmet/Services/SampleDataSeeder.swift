import Foundation
import SwiftData

enum SampleDataSeeder {
    static func seedIfNeeded(in context: ModelContext) throws {
        let existingFlavors = try context.fetch(FetchDescriptor<Flavor>())
        guard existingFlavors.isEmpty else { return }

        let milk = SupplyItem(name: "Leite Integral", category: .dairy, unit: .liter, purchaseCost: 5.9, supplier: "Atacadão do Leite")
        let condensedMilk = SupplyItem(name: "Leite Condensado", category: .dairy, unit: .liter, purchaseCost: 15.0, supplier: "Distribuidora Doce Vida")
        let strawberryPulp = SupplyItem(name: "Polpa de Morango", category: .fruit, unit: .kilogram, purchaseCost: 22.0, supplier: "Polpas da Serra")
        let chocolatePowder = SupplyItem(name: "Chocolate em Pó", category: .sweets, unit: .kilogram, purchaseCost: 28.0, supplier: "Cacau Premium")
        let milkPowder = SupplyItem(name: "Leite em Pó", category: .dairy, unit: .kilogram, purchaseCost: 36.0, supplier: "Distribuidora Doce Vida")
        let sugar = SupplyItem(name: "Açúcar", category: .sweets, unit: .kilogram, purchaseCost: 5.5, supplier: "Mercado Central")
        let bags = SupplyItem(name: "Saquinhos", category: .packaging, unit: .unit, purchaseCost: 0.08, supplier: "EmbalaJá")
        let labels = SupplyItem(name: "Etiquetas", category: .packaging, unit: .unit, purchaseCost: 0.03, supplier: "EmbalaJá")

        [milk, condensedMilk, strawberryPulp, chocolatePowder, milkPowder, sugar, bags, labels].forEach(context.insert)

        try InventoryService.registerSupplyMovement(item: milk, type: .stockIn, quantity: 18, date: .now.addingTimeInterval(-60 * 60 * 24 * 15), note: "Carga inicial", context: context)
        try InventoryService.registerSupplyMovement(item: condensedMilk, type: .stockIn, quantity: 12, date: .now.addingTimeInterval(-60 * 60 * 24 * 15), note: "Carga inicial", context: context)
        try InventoryService.registerSupplyMovement(item: strawberryPulp, type: .stockIn, quantity: 6, date: .now.addingTimeInterval(-60 * 60 * 24 * 12), note: "Carga inicial", context: context)
        try InventoryService.registerSupplyMovement(item: chocolatePowder, type: .stockIn, quantity: 4, date: .now.addingTimeInterval(-60 * 60 * 24 * 12), note: "Carga inicial", context: context)
        try InventoryService.registerSupplyMovement(item: milkPowder, type: .stockIn, quantity: 4, date: .now.addingTimeInterval(-60 * 60 * 24 * 10), note: "Carga inicial", context: context)
        try InventoryService.registerSupplyMovement(item: sugar, type: .stockIn, quantity: 10, date: .now.addingTimeInterval(-60 * 60 * 24 * 10), note: "Carga inicial", context: context)
        try InventoryService.registerSupplyMovement(item: bags, type: .stockIn, quantity: 600, date: .now.addingTimeInterval(-60 * 60 * 24 * 10), note: "Carga inicial", context: context)
        try InventoryService.registerSupplyMovement(item: labels, type: .stockIn, quantity: 500, date: .now.addingTimeInterval(-60 * 60 * 24 * 10), note: "Carga inicial", context: context)

        let strawberry = Flavor(name: "Morango Cremoso", flavorDescription: "Base cremosa com polpa natural de morango.", salePrice: 6.5, minimumStock: 15, notes: "Campeão de vendas")
        let chocolate = Flavor(name: "Chocolate Belga", flavorDescription: "Sabor intenso e cremoso com toque gourmet.", salePrice: 7.0, minimumStock: 12)
        let ninho = Flavor(name: "Ninho Trufado", flavorDescription: "Muito cremoso, com perfil premium.", salePrice: 7.5, minimumStock: 12)
        let passionFruit = Flavor(name: "Maracujá Especial", flavorDescription: "Equilíbrio entre doce e azedinho.", salePrice: 6.5, minimumStock: 10)
        let coconut = Flavor(name: "Coco Cremoso", flavorDescription: "Receita delicada para linha clássica.", salePrice: 6.0, minimumStock: 10, isActive: false)

        [strawberry, chocolate, ninho, passionFruit, coconut].forEach(context.insert)

        let strawberryRecipe = Recipe(title: "Base Padrão Morango", yieldQuantity: 20, notes: "Receita padrão do catálogo", isDefault: true, flavor: strawberry)
        let chocolateRecipe = Recipe(title: "Base Padrão Chocolate", yieldQuantity: 20, notes: "Receita mais vendida de chocolate", isDefault: true, flavor: chocolate)
        let ninhoRecipe = Recipe(title: "Base Premium Ninho", yieldQuantity: 20, notes: "Linha premium", isDefault: true, flavor: ninho)

        [strawberryRecipe, chocolateRecipe, ninhoRecipe].forEach(context.insert)

        [
            RecipeIngredient(quantityUsed: 800, usageUnit: .milliliter, recipe: strawberryRecipe, supplyItem: milk),
            RecipeIngredient(quantityUsed: 450, usageUnit: .milliliter, recipe: strawberryRecipe, supplyItem: condensedMilk),
            RecipeIngredient(quantityUsed: 500, usageUnit: .gram, recipe: strawberryRecipe, supplyItem: strawberryPulp),
            RecipeIngredient(quantityUsed: 20, usageUnit: .unit, recipe: strawberryRecipe, supplyItem: bags),
            RecipeIngredient(quantityUsed: 20, usageUnit: .unit, recipe: strawberryRecipe, supplyItem: labels),

            RecipeIngredient(quantityUsed: 850, usageUnit: .milliliter, recipe: chocolateRecipe, supplyItem: milk),
            RecipeIngredient(quantityUsed: 400, usageUnit: .milliliter, recipe: chocolateRecipe, supplyItem: condensedMilk),
            RecipeIngredient(quantityUsed: 260, usageUnit: .gram, recipe: chocolateRecipe, supplyItem: chocolatePowder),
            RecipeIngredient(quantityUsed: 20, usageUnit: .unit, recipe: chocolateRecipe, supplyItem: bags),
            RecipeIngredient(quantityUsed: 20, usageUnit: .unit, recipe: chocolateRecipe, supplyItem: labels),

            RecipeIngredient(quantityUsed: 900, usageUnit: .milliliter, recipe: ninhoRecipe, supplyItem: milk),
            RecipeIngredient(quantityUsed: 450, usageUnit: .milliliter, recipe: ninhoRecipe, supplyItem: condensedMilk),
            RecipeIngredient(quantityUsed: 220, usageUnit: .gram, recipe: ninhoRecipe, supplyItem: milkPowder),
            RecipeIngredient(quantityUsed: 20, usageUnit: .unit, recipe: ninhoRecipe, supplyItem: bags),
            RecipeIngredient(quantityUsed: 20, usageUnit: .unit, recipe: ninhoRecipe, supplyItem: labels)
        ].forEach(context.insert)

        strawberry.estimatedUnitCost = RecipeCostService.costPerUnit(for: strawberryRecipe)
        chocolate.estimatedUnitCost = RecipeCostService.costPerUnit(for: chocolateRecipe)
        ninho.estimatedUnitCost = RecipeCostService.costPerUnit(for: ninhoRecipe)
        passionFruit.estimatedUnitCost = 2.95
        coconut.estimatedUnitCost = 2.6

        let maria = Customer(name: "Maria Oliveira", phone: "(11) 99888-4411", socialHandle: "@mariaoliveira", neighborhood: "Centro", notes: "Cliente frequente de Pix")
        let joao = Customer(name: "João Santos", phone: "(11) 99777-2200", socialHandle: "@joaosantos", address: "Rua das Flores, 75", neighborhood: "Jardim Bela Vista")
        let fitMarket = Customer(name: "Fit Market", phone: "(11) 99666-1050", socialHandle: "@fitmarket", address: "Av. Central, 345", neighborhood: "Vila Gourmet", notes: "Revenda parceira")

        [maria, joao, fitMarket].forEach(context.insert)
        try context.saveChanges()

        _ = try ProductionService.createBatch(flavor: strawberry, recipe: strawberryRecipe, quantityProduced: 40, date: .now.addingTimeInterval(-60 * 60 * 24 * 7), notes: "Lote semanal", context: context)
        _ = try ProductionService.createBatch(flavor: chocolate, recipe: chocolateRecipe, quantityProduced: 30, date: .now.addingTimeInterval(-60 * 60 * 24 * 6), notes: "Reposição de vitrine", context: context)
        _ = try ProductionService.createBatch(flavor: ninho, recipe: ninhoRecipe, quantityProduced: 25, date: .now.addingTimeInterval(-60 * 60 * 24 * 4), notes: "Lote premium", context: context)

        _ = try SalesService.createSale(
            input: SaleCreationInput(
                customer: maria,
                isWalkIn: false,
                date: .now.addingTimeInterval(-60 * 60 * 18),
                discount: 2,
                amountReceivedNow: 24,
                paymentMethod: .pix,
                dueDate: .now.addingTimeInterval(60 * 60 * 24 * 2),
                notes: "Pedido entregue em domicílio",
                origin: .manual,
                items: [
                    SaleLineInput(flavor: strawberry, quantity: 2, unitPrice: strawberry.salePrice),
                    SaleLineInput(flavor: chocolate, quantity: 2, unitPrice: chocolate.salePrice)
                ]
            ),
            context: context
        )

        _ = try SalesService.createSale(
            input: SaleCreationInput(
                customer: joao,
                isWalkIn: false,
                date: .now.addingTimeInterval(-60 * 60 * 10),
                discount: 0,
                amountReceivedNow: 10,
                paymentMethod: .partial,
                dueDate: .now.addingTimeInterval(-60 * 60 * 24),
                notes: "Saldo para receber amanhã",
                origin: .catalog,
                items: [
                    SaleLineInput(flavor: ninho, quantity: 3, unitPrice: ninho.salePrice)
                ]
            ),
            context: context
        )

        _ = try SalesService.createSale(
            input: SaleCreationInput(
                customer: fitMarket,
                isWalkIn: false,
                date: .now.addingTimeInterval(-60 * 60 * 3),
                discount: 5,
                amountReceivedNow: 30,
                paymentMethod: .pending,
                dueDate: .now.addingTimeInterval(60 * 60 * 24 * 7),
                notes: "Reposição de ponto parceiro",
                origin: .manual,
                items: [
                    SaleLineInput(flavor: strawberry, quantity: 5, unitPrice: 5.8),
                    SaleLineInput(flavor: chocolate, quantity: 5, unitPrice: 6.2)
                ]
            ),
            context: context
        )

        _ = try SalesService.createSale(
            input: SaleCreationInput(
                customer: nil,
                isWalkIn: true,
                date: .now.addingTimeInterval(-60 * 60),
                discount: 0,
                amountReceivedNow: 13,
                paymentMethod: .cash,
                dueDate: .now,
                notes: "Venda rápida no ponto",
                origin: .manual,
                items: [
                    SaleLineInput(flavor: strawberry, quantity: 1, unitPrice: strawberry.salePrice),
                    SaleLineInput(flavor: chocolate, quantity: 1, unitPrice: chocolate.salePrice)
                ]
            ),
            context: context
        )

        let expenses = [
            Expense(title: "Compra de embalagens", category: .packaging, supplier: "EmbalaJá", amount: 180, launchDate: .now.addingTimeInterval(-60 * 60 * 24 * 8), dueDate: .now.addingTimeInterval(-60 * 60 * 24 * 4), paymentMethod: .pix, notes: "Lote mensal", paidAt: .now.addingTimeInterval(-60 * 60 * 24 * 4)),
            Expense(title: "Conta de energia", category: .energy, supplier: "Concessionária", amount: 145.8, launchDate: .now.addingTimeInterval(-60 * 60 * 24 * 2), dueDate: .now.addingTimeInterval(60 * 60 * 24 * 5), notes: "Produção do mês"),
            Expense(title: "Divulgação no Instagram", category: .marketing, supplier: "Mídia Local", amount: 90, launchDate: .now.addingTimeInterval(-60 * 60 * 24), dueDate: .now.addingTimeInterval(60 * 60 * 24 * 3), notes: "Campanha de páscoa")
        ]
        expenses.forEach(context.insert)

        try context.saveChanges()
    }
}

