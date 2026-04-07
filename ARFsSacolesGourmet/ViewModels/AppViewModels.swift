import Foundation
import SwiftData
import SwiftUI

struct EditableSaleLine: Identifiable {
    let id = UUID()
    var flavorID: UUID?
    var quantity: Int = 1
    var unitPrice: Double = 0
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var snapshot = DashboardMetricSnapshot(
        revenueToday: 0,
        revenueMonth: 0,
        receivedTotal: 0,
        receivableTotal: 0,
        payableTotal: 0,
        estimatedProfitMonth: 0,
        lowStockFlavors: [],
        lowStockSupplies: [],
        salesByFlavor: [],
        recentSales: [],
        overdueReceivables: [],
        overdueExpenses: []
    )

    func refresh(
        flavors: [Flavor],
        supplies: [SupplyItem],
        sales: [Sale],
        payments: [PaymentRecord],
        receivables: [Receivable],
        expenses: [Expense]
    ) {
        snapshot = DashboardService.buildSnapshot(
            flavors: flavors,
            supplies: supplies,
            sales: sales,
            payments: payments,
            receivables: receivables,
            expenses: expenses
        )
    }
}

@MainActor
final class SaleComposerViewModel: ObservableObject {
    @Published var isWalkIn = false
    @Published var customerID: UUID?
    @Published var saleDate = Date()
    @Published var discount = 0.0
    @Published var amountReceivedNow = 0.0
    @Published var paymentMethod: PaymentMethod = .pix
    @Published var dueDate = Date()
    @Published var notes = ""
    @Published var origin: SaleOrigin = .manual
    @Published var autoOpenWhatsApp = true
    @Published var lines: [EditableSaleLine] = [EditableSaleLine()]

    func addLine() {
        lines.append(EditableSaleLine())
    }

    func removeLine(at offsets: IndexSet) {
        lines.remove(atOffsets: offsets)
        if lines.isEmpty {
            lines = [EditableSaleLine()]
        }
    }

    func syncPrice(for lineID: UUID, flavors: [Flavor]) {
        guard let index = lines.firstIndex(where: { $0.id == lineID }),
              let flavorID = lines[index].flavorID,
              let flavor = flavors.first(where: { $0.id == flavorID }) else { return }
        lines[index].unitPrice = flavor.salePrice
    }

    func subtotal(using flavors: [Flavor]) -> Double {
        lines.reduce(0) { partialResult, line in
            guard let flavorID = line.flavorID,
                  let flavor = flavors.first(where: { $0.id == flavorID }) else {
                return partialResult
            }
            let price = line.unitPrice == 0 ? flavor.salePrice : line.unitPrice
            return partialResult + (Double(line.quantity) * price)
        }
    }

    func total(using flavors: [Flavor]) -> Double {
        max(subtotal(using: flavors) - discount, 0)
    }

    func buildInput(customers: [Customer], flavors: [Flavor]) throws -> SaleCreationInput {
        if !isWalkIn && customerID == nil {
            throw BusinessError.invalidData("Selecione um cliente ou marque como cliente avulso.")
        }

        let saleItems = try lines.map { line -> SaleLineInput in
            guard let flavorID = line.flavorID,
                  let flavor = flavors.first(where: { $0.id == flavorID }) else {
                throw BusinessError.invalidData("Selecione um sabor em todas as linhas.")
            }
            let price = line.unitPrice == 0 ? flavor.salePrice : line.unitPrice
            return SaleLineInput(flavor: flavor, quantity: max(line.quantity, 1), unitPrice: price)
        }

        return SaleCreationInput(
            customer: customers.first(where: { $0.id == customerID }),
            isWalkIn: isWalkIn,
            date: saleDate,
            discount: discount,
            amountReceivedNow: amountReceivedNow,
            paymentMethod: paymentMethod,
            dueDate: dueDate,
            notes: notes,
            origin: origin,
            items: saleItems
        )
    }

    func reset(origin: SaleOrigin = .manual) {
        isWalkIn = false
        customerID = nil
        saleDate = .now
        discount = 0
        amountReceivedNow = 0
        paymentMethod = .pix
        dueDate = .now
        notes = ""
        autoOpenWhatsApp = true
        self.origin = origin
        lines = [EditableSaleLine()]
    }
}

@MainActor
final class ProductionDraftViewModel: ObservableObject {
    @Published var flavorID: UUID?
    @Published var recipeID: UUID?
    @Published var productionDate = Date()
    @Published var quantityProduced = 20
    @Published var notes = ""

    func estimatedTotalCost(recipes: [Recipe]) -> Double {
        guard let recipeID,
              let recipe = recipes.first(where: { $0.id == recipeID }),
              recipe.yieldQuantity > 0 else {
            return 0
        }
        let factor = Double(quantityProduced) / Double(recipe.yieldQuantity)
        return RecipeCostService.totalCost(for: recipe) * factor
    }
}

@MainActor
final class ReportsViewModel: ObservableObject {
    @Published var period: AnalyticsPeriod = .month
    @Published var customStart = Date().startOfMonthInBrazil
    @Published var customEnd = Date()

    func range(reference: Date = .now) -> ClosedRange<Date> {
        period.range(reference: reference, customStart: customStart, customEnd: customEnd)
    }

    func financeSummary(sales: [Sale], payments: [PaymentRecord], expenses: [Expense]) -> FinanceSummary {
        FinanceService.summary(sales: sales, payments: payments, expenses: expenses, range: range())
    }

    func salesCSVDocument(sales: [Sale]) -> TextExportDocument {
        let filtered = sales.filter { range().contains($0.saleDate) }
        return TextExportDocument(text: CSVExporter.salesCSV(for: filtered))
    }

    func financeCSVDocument(sales: [Sale], payments: [PaymentRecord], expenses: [Expense]) -> TextExportDocument {
        let summary = financeSummary(sales: sales, payments: payments, expenses: expenses)
        return TextExportDocument(text: CSVExporter.financeSummaryCSV(summary: summary))
    }
}
