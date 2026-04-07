import Foundation
import SwiftData

enum BusinessError: LocalizedError {
    case invalidData(String)
    case insufficientStock(item: String)
    case missingRecipe
    case missingFlavor
    case missingCustomerPhone

    var errorDescription: String? {
        switch self {
        case .invalidData(let message):
            return message
        case .insufficientStock(let item):
            return "Estoque insuficiente para \(item)."
        case .missingRecipe:
            return "Selecione uma ficha técnica válida."
        case .missingFlavor:
            return "Selecione um sabor válido."
        case .missingCustomerPhone:
            return "O cliente precisa ter telefone cadastrado para abrir o WhatsApp."
        }
    }
}

struct SaleLineInput {
    let flavor: Flavor
    let quantity: Int
    let unitPrice: Double
}

struct SaleCreationInput {
    let customer: Customer?
    let isWalkIn: Bool
    let date: Date
    let discount: Double
    let amountReceivedNow: Double
    let paymentMethod: PaymentMethod
    let dueDate: Date
    let notes: String
    let origin: SaleOrigin
    let items: [SaleLineInput]
}

struct DashboardMetricSnapshot {
    let revenueToday: Double
    let revenueMonth: Double
    let receivedTotal: Double
    let receivableTotal: Double
    let payableTotal: Double
    let estimatedProfitMonth: Double
    let lowStockFlavors: [Flavor]
    let lowStockSupplies: [SupplyItem]
    let salesByFlavor: [FlavorSalesSummary]
    let recentSales: [Sale]
    let overdueReceivables: [Receivable]
    let overdueExpenses: [Expense]
}

struct FlavorSalesSummary: Identifiable {
    let id = UUID()
    let name: String
    let quantity: Int
    let revenue: Double
}

struct FinanceSummary {
    let entries: Double
    let exits: Double
    let balance: Double
    let revenue: Double
    let costOfGoodsSold: Double
    let operationalExpenses: Double
    let grossProfit: Double
    let netProfit: Double
}

struct ExpenseCategorySummary: Identifiable {
    let id = UUID()
    let category: ExpenseCategory
    let amount: Double
}

struct ClientRevenueSummary: Identifiable {
    let id = UUID()
    let customerName: String
    let amount: Double
}

extension ModelContext {
    func saveChanges() throws {
        try save()
    }
}

enum RecipeCostService {
    static func baseQuantity(for ingredient: RecipeIngredient) throws -> Double {
        guard let supply = ingredient.supplyItem else {
            throw BusinessError.invalidData("Ingrediente sem insumo vinculado.")
        }
        guard ingredient.usageUnit.isCompatible(with: supply.unit) else {
            throw BusinessError.invalidData("A unidade de uso de \(supply.name) não é compatível com o insumo.")
        }
        return ingredient.usageUnit.toBase(ingredient.quantityUsed)
    }

    static func ingredientCost(_ ingredient: RecipeIngredient) throws -> Double {
        guard let supply = ingredient.supplyItem else {
            return 0
        }
        let baseQuantity = try baseQuantity(for: ingredient)
        let costPerBase = supply.purchaseCost / supply.unit.baseFactor
        return baseQuantity * costPerBase
    }

    static func totalCost(for recipe: Recipe) -> Double {
        recipe.ingredients.reduce(0) { partialResult, ingredient in
            partialResult + ((try? ingredientCost(ingredient)) ?? 0)
        }
    }

    static func costPerUnit(for recipe: Recipe) -> Double {
        guard recipe.yieldQuantity > 0 else { return 0 }
        return totalCost(for: recipe) / Double(recipe.yieldQuantity)
    }
}

enum InventoryService {
    static func registerSupplyMovement(
        item: SupplyItem,
        type: SupplyMovementType,
        quantity: Double,
        date: Date = .now,
        note: String = "",
        context: ModelContext
    ) throws {
        guard quantity > 0 else {
            throw BusinessError.invalidData("Informe uma quantidade maior que zero.")
        }

        let previous = item.currentStock
        let newValue: Double

        switch type {
        case .stockIn:
            newValue = previous + quantity
        case .stockOut, .production:
            guard previous >= quantity else {
                throw BusinessError.insufficientStock(item: item.name)
            }
            newValue = previous - quantity
        case .adjustment:
            newValue = quantity
        }

        item.currentStock = newValue
        item.updatedAt = date
        if type == .stockIn {
            item.lastPurchaseDate = date
        }

        let movement = SupplyMovement(
            movementDate: date,
            type: type,
            quantity: quantity,
            previousQuantity: previous,
            newQuantity: newValue,
            notes: note,
            unitCostSnapshot: item.purchaseCost,
            supplyItem: item
        )
        context.insert(movement)
        try context.saveChanges()
    }

    static func requiredSupplyQuantityInSupplyUnit(
        ingredient: RecipeIngredient,
        factor: Double
    ) throws -> Double {
        guard let supply = ingredient.supplyItem else {
            throw BusinessError.invalidData("Ingrediente sem insumo.")
        }

        let baseQuantity = try RecipeCostService.baseQuantity(for: ingredient) * factor
        return supply.unit.fromBase(baseQuantity)
    }
}

enum ProductionService {
    static func createBatch(
        flavor: Flavor,
        recipe: Recipe,
        quantityProduced: Int,
        date: Date,
        notes: String,
        context: ModelContext
    ) throws -> ProductionBatch {
        guard quantityProduced > 0 else {
            throw BusinessError.invalidData("A quantidade produzida deve ser maior que zero.")
        }
        guard recipe.yieldQuantity > 0 else {
            throw BusinessError.invalidData("O rendimento da receita deve ser maior que zero.")
        }

        let factor = Double(quantityProduced) / Double(recipe.yieldQuantity)

        for ingredient in recipe.ingredients {
            guard let supply = ingredient.supplyItem else { continue }
            let quantityInSupplyUnit = try InventoryService.requiredSupplyQuantityInSupplyUnit(ingredient: ingredient, factor: factor)
            if supply.currentStock < quantityInSupplyUnit {
                throw BusinessError.insufficientStock(item: supply.name)
            }
        }

        for ingredient in recipe.ingredients {
            guard let supply = ingredient.supplyItem else { continue }
            let quantityInSupplyUnit = try InventoryService.requiredSupplyQuantityInSupplyUnit(ingredient: ingredient, factor: factor)
            let note = "Consumo para produção do sabor \(flavor.name)"
            try InventoryService.registerSupplyMovement(
                item: supply,
                type: .production,
                quantity: quantityInSupplyUnit,
                date: date,
                note: note,
                context: context
            )
        }

        let totalCost = RecipeCostService.totalCost(for: recipe) * factor
        let unitCost = totalCost / Double(quantityProduced)

        let batch = ProductionBatch(
            productionDate: date,
            quantityProduced: quantityProduced,
            totalCost: totalCost,
            unitCost: unitCost,
            notes: notes,
            flavor: flavor,
            recipe: recipe
        )
        flavor.stockQuantity += quantityProduced
        flavor.estimatedUnitCost = unitCost
        flavor.updatedAt = date

        context.insert(batch)
        try context.saveChanges()
        return batch
    }
}

enum SalesService {
    static func createSale(
        input: SaleCreationInput,
        context: ModelContext
    ) throws -> Sale {
        guard !input.items.isEmpty else {
            throw BusinessError.invalidData("Adicione pelo menos um sabor na venda.")
        }

        for line in input.items {
            guard line.quantity > 0 else {
                throw BusinessError.invalidData("A quantidade de cada item deve ser maior que zero.")
            }
            guard line.flavor.stockQuantity >= line.quantity else {
                throw BusinessError.insufficientStock(item: line.flavor.name)
            }
        }

        let subtotal = input.items.reduce(0) { $0 + (Double($1.quantity) * $1.unitPrice) }
        let total = max(subtotal - input.discount, 0)
        guard input.amountReceivedNow <= total else {
            throw BusinessError.invalidData("O valor recebido não pode ser maior que o total da venda.")
        }

        let customerName = input.isWalkIn ? "Cliente avulso" : (input.customer?.name ?? "Cliente não informado")
        let sale = Sale(
            saleDate: input.date,
            customerNameSnapshot: customerName,
            discountAmount: input.discount,
            subtotalAmount: subtotal,
            totalAmount: total,
            notes: input.notes,
            paymentMethod: input.paymentMethod,
            origin: input.origin,
            customer: input.customer
        )
        context.insert(sale)

        for line in input.items {
            let item = SaleItem(
                quantity: line.quantity,
                unitPrice: line.unitPrice,
                unitCostSnapshot: line.flavor.estimatedUnitCost,
                sale: sale,
                flavor: line.flavor
            )
            line.flavor.stockQuantity -= line.quantity
            line.flavor.updatedAt = input.date
            context.insert(item)
        }

        let openBalance = total - input.amountReceivedNow
        var receivable: Receivable?

        if openBalance > 0 {
            let record = Receivable(
                totalAmount: total,
                dueDate: input.dueDate,
                notes: "Saldo pendente da venda de \(input.date.brDate)",
                createdAt: input.date,
                sale: sale,
                customer: input.customer
            )
            sale.receivable = record
            receivable = record
            context.insert(record)
        }

        if input.amountReceivedNow > 0 {
            let payment = PaymentRecord(
                amount: input.amountReceivedNow,
                paymentDate: input.date,
                method: input.paymentMethod,
                notes: "Recebimento registrado no fechamento da venda",
                sale: sale,
                receivable: receivable,
                customer: input.customer
            )
            context.insert(payment)
        }

        try context.saveChanges()
        return sale
    }
}

enum ReceivablesService {
    static func registerPayment(
        receivable: Receivable,
        amount: Double,
        method: PaymentMethod,
        date: Date,
        notes: String,
        context: ModelContext
    ) throws {
        guard amount > 0 else {
            throw BusinessError.invalidData("Informe um valor de recebimento maior que zero.")
        }
        guard amount <= receivable.balance else {
            throw BusinessError.invalidData("O valor informado é maior que o saldo pendente.")
        }

        let record = PaymentRecord(
            amount: amount,
            paymentDate: date,
            method: method,
            notes: notes,
            sale: receivable.sale,
            receivable: receivable,
            customer: receivable.customer
        )
        context.insert(record)
        try context.saveChanges()
    }
}

enum ExpenseService {
    static func markAsPaid(
        expense: Expense,
        method: PaymentMethod,
        paidAt: Date,
        context: ModelContext
    ) throws {
        expense.paymentMethod = method
        expense.paidAt = paidAt
        try context.saveChanges()
    }
}

enum DashboardService {
    static func buildSnapshot(
        flavors: [Flavor],
        supplies: [SupplyItem],
        sales: [Sale],
        payments: [PaymentRecord],
        receivables: [Receivable],
        expenses: [Expense],
        referenceDate: Date = .now
    ) -> DashboardMetricSnapshot {
        let todayRange = referenceDate.startOfDayInBrazil ... referenceDate.endOfDayInBrazil
        let monthRange = referenceDate.startOfMonthInBrazil ... referenceDate.endOfMonthInBrazil

        let revenueToday = sales
            .filter { todayRange.contains($0.saleDate) }
            .reduce(0) { $0 + $1.totalAmount }

        let revenueMonth = sales
            .filter { monthRange.contains($0.saleDate) }
            .reduce(0) { $0 + $1.totalAmount }

        let receivedTotal = payments.reduce(0) { $0 + $1.amount }
        let receivableTotal = receivables.reduce(0) { $0 + $1.balance }
        let payableTotal = expenses.filter { !$0.isPaid }.reduce(0) { $0 + $1.amount }
        let estimatedProfitMonth = FinanceService.summary(
            sales: sales,
            payments: payments,
            expenses: expenses,
            range: monthRange
        ).netProfit

        let lowStockFlavors = flavors.filter { $0.isLowStock }.sorted { $0.stockQuantity < $1.stockQuantity }
        let lowStockSupplies = supplies.filter { $0.isLowStock }.sorted { $0.currentStock < $1.currentStock }
        let overdueReceivables = receivables.filter { $0.balance > 0 && $0.dueDate < referenceDate.startOfDayInBrazil }
        let overdueExpenses = expenses.filter { !$0.isPaid && $0.dueDate < referenceDate.startOfDayInBrazil }

        let salesByFlavor = sales
            .filter { monthRange.contains($0.saleDate) }
            .flatMap(\.items)
            .reduce(into: [String: FlavorSalesSummary]()) { partialResult, item in
                let key = item.flavor?.name ?? "Sem sabor"
                let current = partialResult[key] ?? FlavorSalesSummary(name: key, quantity: 0, revenue: 0)
                partialResult[key] = FlavorSalesSummary(
                    name: key,
                    quantity: current.quantity + item.quantity,
                    revenue: current.revenue + item.lineTotal
                )
            }
            .values
            .sorted { $0.quantity > $1.quantity }

        let recentSales = sales.sorted { $0.saleDate > $1.saleDate }.prefix(5)

        return DashboardMetricSnapshot(
            revenueToday: revenueToday,
            revenueMonth: revenueMonth,
            receivedTotal: receivedTotal,
            receivableTotal: receivableTotal,
            payableTotal: payableTotal,
            estimatedProfitMonth: estimatedProfitMonth,
            lowStockFlavors: lowStockFlavors,
            lowStockSupplies: lowStockSupplies,
            salesByFlavor: Array(salesByFlavor.prefix(6)),
            recentSales: Array(recentSales),
            overdueReceivables: overdueReceivables,
            overdueExpenses: overdueExpenses
        )
    }
}

enum FinanceService {
    static func summary(
        sales: [Sale],
        payments: [PaymentRecord],
        expenses: [Expense],
        range: ClosedRange<Date>
    ) -> FinanceSummary {
        let periodSales = sales.filter { range.contains($0.saleDate) }
        let entries = payments.filter { range.contains($0.paymentDate) }.reduce(0) { $0 + $1.amount }
        let exits = expenses
            .filter { expense in
                guard let paidAt = expense.paidAt else { return false }
                return range.contains(paidAt)
            }
            .reduce(0) { $0 + $1.amount }
        let revenue = periodSales.reduce(0) { $0 + $1.totalAmount }
        let costOfGoodsSold = periodSales.flatMap(\.items).reduce(0) { $0 + $1.lineCost }
        let operationalExpenses = expenses.filter { range.contains($0.launchDate) }.reduce(0) { $0 + $1.amount }
        let grossProfit = revenue - costOfGoodsSold
        let netProfit = grossProfit - operationalExpenses

        return FinanceSummary(
            entries: entries,
            exits: exits,
            balance: entries - exits,
            revenue: revenue,
            costOfGoodsSold: costOfGoodsSold,
            operationalExpenses: operationalExpenses,
            grossProfit: grossProfit,
            netProfit: netProfit
        )
    }

    static func salesByFlavor(sales: [Sale], range: ClosedRange<Date>) -> [FlavorSalesSummary] {
        sales
            .filter { range.contains($0.saleDate) }
            .flatMap(\.items)
            .reduce(into: [String: FlavorSalesSummary]()) { result, item in
                let key = item.flavor?.name ?? "Sem sabor"
                let current = result[key] ?? FlavorSalesSummary(name: key, quantity: 0, revenue: 0)
                result[key] = FlavorSalesSummary(
                    name: key,
                    quantity: current.quantity + item.quantity,
                    revenue: current.revenue + item.lineTotal
                )
            }
            .values
            .sorted { $0.revenue > $1.revenue }
    }

    static func clientRevenue(sales: [Sale], range: ClosedRange<Date>) -> [ClientRevenueSummary] {
        sales
            .filter { range.contains($0.saleDate) }
            .reduce(into: [String: Double]()) { result, sale in
                result[sale.customerNameSnapshot, default: 0] += sale.totalAmount
            }
            .map { ClientRevenueSummary(customerName: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    static func expensesByCategory(expenses: [Expense], range: ClosedRange<Date>) -> [ExpenseCategorySummary] {
        expenses
            .filter { range.contains($0.launchDate) }
            .reduce(into: [ExpenseCategory: Double]()) { result, expense in
                result[expense.category, default: 0] += expense.amount
            }
            .map { ExpenseCategorySummary(category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }
}

enum WhatsAppMessageBuilder {
    static func message(for sale: Sale) -> String {
        let items = sale.items
            .sorted { ($0.flavor?.name ?? "") < ($1.flavor?.name ?? "") }
            .map { item in
                let name = item.flavor?.name ?? "Sabor removido"
                return "- \(item.quantity)x \(name): \(item.lineTotal.brlCurrency)"
            }
            .joined(separator: "\n")

        return """
        Olá, \(sale.customerNameSnapshot)!

        Segue o resumo da sua compra em \(sale.saleDate.brDate):
        \(items)

        Total da compra: \(sale.totalAmount.brlCurrency)
        Valor já recebido: \(sale.amountReceived.brlCurrency)
        Saldo pendente: \(sale.amountOpen.brlCurrency)
        Status do pagamento: \(sale.paymentStatusLabel)

        Pedido registrado em ARF's Sacolés Gourmet.
        """
    }

    static func url(for sale: Sale) throws -> URL {
        guard let phone = sale.customer?.phone, !phone.isEmpty else {
            throw BusinessError.missingCustomerPhone
        }
        let message = message(for: sale).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let number = phone.normalizedWhatsAppPhone
        guard let url = URL(string: "https://wa.me/\(number)?text=\(message)") else {
            throw BusinessError.invalidData("Não foi possível montar o link do WhatsApp.")
        }
        return url
    }
}
