import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct TextExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }
    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct BackupPayload: Codable {
    var exportedAt: Date
    var flavors: [FlavorDTO]
    var supplies: [SupplyItemDTO]
    var supplyMovements: [SupplyMovementDTO]
    var customers: [CustomerDTO]
    var recipes: [RecipeDTO]
    var recipeIngredients: [RecipeIngredientDTO]
    var productionBatches: [ProductionBatchDTO]
    var sales: [SaleDTO]
    var saleItems: [SaleItemDTO]
    var receivables: [ReceivableDTO]
    var paymentRecords: [PaymentRecordDTO]
    var expenses: [ExpenseDTO]
}

struct FlavorDTO: Codable {
    let id: UUID
    let name: String
    let flavorDescription: String
    let salePrice: Double
    let estimatedUnitCost: Double
    let stockQuantity: Int
    let minimumStock: Int
    let isActive: Bool
    let notes: String
    let createdAt: Date
    let updatedAt: Date
}

struct SupplyItemDTO: Codable {
    let id: UUID
    let name: String
    let category: SupplyCategory
    let unit: UnitOfMeasure
    let currentStock: Double
    let minimumStock: Double
    let purchaseCost: Double
    let supplier: String
    let lastPurchaseDate: Date?
    let notes: String
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
}

struct SupplyMovementDTO: Codable {
    let id: UUID
    let movementDate: Date
    let type: SupplyMovementType
    let quantity: Double
    let previousQuantity: Double
    let newQuantity: Double
    let notes: String
    let unitCostSnapshot: Double
    let supplyID: UUID?
}

struct CustomerDTO: Codable {
    let id: UUID
    let name: String
    let phone: String
    let socialHandle: String
    let address: String
    let neighborhood: String
    let notes: String
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
}

struct RecipeDTO: Codable {
    let id: UUID
    let title: String
    let yieldQuantity: Int
    let notes: String
    let isDefault: Bool
    let createdAt: Date
    let updatedAt: Date
    let flavorID: UUID?
}

struct RecipeIngredientDTO: Codable {
    let id: UUID
    let quantityUsed: Double
    let usageUnit: UnitOfMeasure
    let notes: String
    let recipeID: UUID?
    let supplyID: UUID?
}

struct ProductionBatchDTO: Codable {
    let id: UUID
    let productionDate: Date
    let quantityProduced: Int
    let totalCost: Double
    let unitCost: Double
    let notes: String
    let flavorID: UUID?
    let recipeID: UUID?
}

struct SaleDTO: Codable {
    let id: UUID
    let saleDate: Date
    let customerNameSnapshot: String
    let discountAmount: Double
    let subtotalAmount: Double
    let totalAmount: Double
    let notes: String
    let paymentMethod: PaymentMethod
    let origin: SaleOrigin
    let customerID: UUID?
}

struct SaleItemDTO: Codable {
    let id: UUID
    let quantity: Int
    let unitPrice: Double
    let unitCostSnapshot: Double
    let saleID: UUID?
    let flavorID: UUID?
}

struct ReceivableDTO: Codable {
    let id: UUID
    let totalAmount: Double
    let dueDate: Date
    let notes: String
    let createdAt: Date
    let saleID: UUID?
    let customerID: UUID?
}

struct PaymentRecordDTO: Codable {
    let id: UUID
    let amount: Double
    let paymentDate: Date
    let method: PaymentMethod
    let notes: String
    let saleID: UUID?
    let receivableID: UUID?
    let customerID: UUID?
}

struct ExpenseDTO: Codable {
    let id: UUID
    let title: String
    let category: ExpenseCategory
    let supplier: String
    let amount: Double
    let launchDate: Date
    let dueDate: Date
    let paymentMethod: PaymentMethod?
    let notes: String
    let paidAt: Date?
}

enum CSVExporter {
    static func salesCSV(for sales: [Sale]) -> String {
        let header = "data,cliente,origem,pagamento,total,recebido,em_aberto"
        let rows = sales.sorted { $0.saleDate > $1.saleDate }.map { sale in
            [
                sale.saleDate.brDate,
                escape(sale.customerNameSnapshot),
                escape(sale.origin.rawValue),
                escape(sale.paymentMethod.rawValue),
                String(format: "%.2f", sale.totalAmount),
                String(format: "%.2f", sale.amountReceived),
                String(format: "%.2f", sale.amountOpen)
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    static func financeSummaryCSV(summary: FinanceSummary) -> String {
        """
        indicador,valor
        Entradas,\(String(format: "%.2f", summary.entries))
        Saídas,\(String(format: "%.2f", summary.exits))
        Saldo,\(String(format: "%.2f", summary.balance))
        Faturamento,\(String(format: "%.2f", summary.revenue))
        CPV,\(String(format: "%.2f", summary.costOfGoodsSold))
        Despesas Operacionais,\(String(format: "%.2f", summary.operationalExpenses))
        Lucro Bruto,\(String(format: "%.2f", summary.grossProfit))
        Lucro Líquido,\(String(format: "%.2f", summary.netProfit))
        """
    }

    private static func escape(_ text: String) -> String {
        "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

enum BackupService {
    static func exportBackup(context: ModelContext) throws -> Data {
        let payload = BackupPayload(
            exportedAt: .now,
            flavors: try context.fetch(FetchDescriptor<Flavor>()).map {
                FlavorDTO(
                    id: $0.id,
                    name: $0.name,
                    flavorDescription: $0.flavorDescription,
                    salePrice: $0.salePrice,
                    estimatedUnitCost: $0.estimatedUnitCost,
                    stockQuantity: $0.stockQuantity,
                    minimumStock: $0.minimumStock,
                    isActive: $0.isActive,
                    notes: $0.notes,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt
                )
            },
            supplies: try context.fetch(FetchDescriptor<SupplyItem>()).map {
                SupplyItemDTO(
                    id: $0.id,
                    name: $0.name,
                    category: $0.category,
                    unit: $0.unit,
                    currentStock: $0.currentStock,
                    minimumStock: $0.minimumStock,
                    purchaseCost: $0.purchaseCost,
                    supplier: $0.supplier,
                    lastPurchaseDate: $0.lastPurchaseDate,
                    notes: $0.notes,
                    isActive: $0.isActive,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt
                )
            },
            supplyMovements: try context.fetch(FetchDescriptor<SupplyMovement>()).map {
                SupplyMovementDTO(
                    id: $0.id,
                    movementDate: $0.movementDate,
                    type: $0.type,
                    quantity: $0.quantity,
                    previousQuantity: $0.previousQuantity,
                    newQuantity: $0.newQuantity,
                    notes: $0.notes,
                    unitCostSnapshot: $0.unitCostSnapshot,
                    supplyID: $0.supplyItem?.id
                )
            },
            customers: try context.fetch(FetchDescriptor<Customer>()).map {
                CustomerDTO(
                    id: $0.id,
                    name: $0.name,
                    phone: $0.phone,
                    socialHandle: $0.socialHandle,
                    address: $0.address,
                    neighborhood: $0.neighborhood,
                    notes: $0.notes,
                    isActive: $0.isActive,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt
                )
            },
            recipes: try context.fetch(FetchDescriptor<Recipe>()).map {
                RecipeDTO(
                    id: $0.id,
                    title: $0.title,
                    yieldQuantity: $0.yieldQuantity,
                    notes: $0.notes,
                    isDefault: $0.isDefault,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt,
                    flavorID: $0.flavor?.id
                )
            },
            recipeIngredients: try context.fetch(FetchDescriptor<RecipeIngredient>()).map {
                RecipeIngredientDTO(
                    id: $0.id,
                    quantityUsed: $0.quantityUsed,
                    usageUnit: $0.usageUnit,
                    notes: $0.notes,
                    recipeID: $0.recipe?.id,
                    supplyID: $0.supplyItem?.id
                )
            },
            productionBatches: try context.fetch(FetchDescriptor<ProductionBatch>()).map {
                ProductionBatchDTO(
                    id: $0.id,
                    productionDate: $0.productionDate,
                    quantityProduced: $0.quantityProduced,
                    totalCost: $0.totalCost,
                    unitCost: $0.unitCost,
                    notes: $0.notes,
                    flavorID: $0.flavor?.id,
                    recipeID: $0.recipe?.id
                )
            },
            sales: try context.fetch(FetchDescriptor<Sale>()).map {
                SaleDTO(
                    id: $0.id,
                    saleDate: $0.saleDate,
                    customerNameSnapshot: $0.customerNameSnapshot,
                    discountAmount: $0.discountAmount,
                    subtotalAmount: $0.subtotalAmount,
                    totalAmount: $0.totalAmount,
                    notes: $0.notes,
                    paymentMethod: $0.paymentMethod,
                    origin: $0.origin,
                    customerID: $0.customer?.id
                )
            },
            saleItems: try context.fetch(FetchDescriptor<SaleItem>()).map {
                SaleItemDTO(
                    id: $0.id,
                    quantity: $0.quantity,
                    unitPrice: $0.unitPrice,
                    unitCostSnapshot: $0.unitCostSnapshot,
                    saleID: $0.sale?.id,
                    flavorID: $0.flavor?.id
                )
            },
            receivables: try context.fetch(FetchDescriptor<Receivable>()).map {
                ReceivableDTO(
                    id: $0.id,
                    totalAmount: $0.totalAmount,
                    dueDate: $0.dueDate,
                    notes: $0.notes,
                    createdAt: $0.createdAt,
                    saleID: $0.sale?.id,
                    customerID: $0.customer?.id
                )
            },
            paymentRecords: try context.fetch(FetchDescriptor<PaymentRecord>()).map {
                PaymentRecordDTO(
                    id: $0.id,
                    amount: $0.amount,
                    paymentDate: $0.paymentDate,
                    method: $0.method,
                    notes: $0.notes,
                    saleID: $0.sale?.id,
                    receivableID: $0.receivable?.id,
                    customerID: $0.customer?.id
                )
            },
            expenses: try context.fetch(FetchDescriptor<Expense>()).map {
                ExpenseDTO(
                    id: $0.id,
                    title: $0.title,
                    category: $0.category,
                    supplier: $0.supplier,
                    amount: $0.amount,
                    launchDate: $0.launchDate,
                    dueDate: $0.dueDate,
                    paymentMethod: $0.paymentMethod,
                    notes: $0.notes,
                    paidAt: $0.paidAt
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    static func importBackup(data: Data, context: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(BackupPayload.self, from: data)

        try clearAll(context: context)

        var flavors: [UUID: Flavor] = [:]
        var supplies: [UUID: SupplyItem] = [:]
        var customers: [UUID: Customer] = [:]
        var recipes: [UUID: Recipe] = [:]
        var sales: [UUID: Sale] = [:]
        var receivables: [UUID: Receivable] = [:]

        for dto in payload.flavors {
            let model = Flavor(
                id: dto.id,
                name: dto.name,
                flavorDescription: dto.flavorDescription,
                salePrice: dto.salePrice,
                estimatedUnitCost: dto.estimatedUnitCost,
                stockQuantity: dto.stockQuantity,
                minimumStock: dto.minimumStock,
                isActive: dto.isActive,
                notes: dto.notes,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt
            )
            context.insert(model)
            flavors[dto.id] = model
        }

        for dto in payload.supplies {
            let model = SupplyItem(
                id: dto.id,
                name: dto.name,
                category: dto.category,
                unit: dto.unit,
                currentStock: dto.currentStock,
                minimumStock: dto.minimumStock,
                purchaseCost: dto.purchaseCost,
                supplier: dto.supplier,
                lastPurchaseDate: dto.lastPurchaseDate,
                notes: dto.notes,
                isActive: dto.isActive,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt
            )
            context.insert(model)
            supplies[dto.id] = model
        }

        for dto in payload.customers {
            let model = Customer(
                id: dto.id,
                name: dto.name,
                phone: dto.phone,
                socialHandle: dto.socialHandle,
                address: dto.address,
                neighborhood: dto.neighborhood,
                notes: dto.notes,
                isActive: dto.isActive,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt
            )
            context.insert(model)
            customers[dto.id] = model
        }

        for dto in payload.recipes {
            let model = Recipe(
                id: dto.id,
                title: dto.title,
                yieldQuantity: dto.yieldQuantity,
                notes: dto.notes,
                isDefault: dto.isDefault,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt,
                flavor: dto.flavorID.flatMap { flavors[$0] }
            )
            context.insert(model)
            recipes[dto.id] = model
        }

        for dto in payload.recipeIngredients {
            let model = RecipeIngredient(
                id: dto.id,
                quantityUsed: dto.quantityUsed,
                usageUnit: dto.usageUnit,
                notes: dto.notes,
                recipe: dto.recipeID.flatMap { recipes[$0] },
                supplyItem: dto.supplyID.flatMap { supplies[$0] }
            )
            context.insert(model)
        }

        for dto in payload.productionBatches {
            let model = ProductionBatch(
                id: dto.id,
                productionDate: dto.productionDate,
                quantityProduced: dto.quantityProduced,
                totalCost: dto.totalCost,
                unitCost: dto.unitCost,
                notes: dto.notes,
                flavor: dto.flavorID.flatMap { flavors[$0] },
                recipe: dto.recipeID.flatMap { recipes[$0] }
            )
            context.insert(model)
        }

        for dto in payload.sales {
            let model = Sale(
                id: dto.id,
                saleDate: dto.saleDate,
                customerNameSnapshot: dto.customerNameSnapshot,
                discountAmount: dto.discountAmount,
                subtotalAmount: dto.subtotalAmount,
                totalAmount: dto.totalAmount,
                notes: dto.notes,
                paymentMethod: dto.paymentMethod,
                origin: dto.origin,
                customer: dto.customerID.flatMap { customers[$0] }
            )
            context.insert(model)
            sales[dto.id] = model
        }

        for dto in payload.saleItems {
            let model = SaleItem(
                id: dto.id,
                quantity: dto.quantity,
                unitPrice: dto.unitPrice,
                unitCostSnapshot: dto.unitCostSnapshot,
                sale: dto.saleID.flatMap { sales[$0] },
                flavor: dto.flavorID.flatMap { flavors[$0] }
            )
            context.insert(model)
        }

        for dto in payload.receivables {
            let model = Receivable(
                id: dto.id,
                totalAmount: dto.totalAmount,
                dueDate: dto.dueDate,
                notes: dto.notes,
                createdAt: dto.createdAt,
                sale: dto.saleID.flatMap { sales[$0] },
                customer: dto.customerID.flatMap { customers[$0] }
            )
            context.insert(model)
            receivables[dto.id] = model
            if let sale = dto.saleID.flatMap({ sales[$0] }) {
                sale.receivable = model
            }
        }

        for dto in payload.paymentRecords {
            let model = PaymentRecord(
                id: dto.id,
                amount: dto.amount,
                paymentDate: dto.paymentDate,
                method: dto.method,
                notes: dto.notes,
                sale: dto.saleID.flatMap { sales[$0] },
                receivable: dto.receivableID.flatMap { receivables[$0] },
                customer: dto.customerID.flatMap { customers[$0] }
            )
            context.insert(model)
        }

        for dto in payload.supplyMovements {
            let model = SupplyMovement(
                id: dto.id,
                movementDate: dto.movementDate,
                type: dto.type,
                quantity: dto.quantity,
                previousQuantity: dto.previousQuantity,
                newQuantity: dto.newQuantity,
                notes: dto.notes,
                unitCostSnapshot: dto.unitCostSnapshot,
                supplyItem: dto.supplyID.flatMap { supplies[$0] }
            )
            context.insert(model)
        }

        for dto in payload.expenses {
            let model = Expense(
                id: dto.id,
                title: dto.title,
                category: dto.category,
                supplier: dto.supplier,
                amount: dto.amount,
                launchDate: dto.launchDate,
                dueDate: dto.dueDate,
                paymentMethod: dto.paymentMethod,
                notes: dto.notes,
                paidAt: dto.paidAt
            )
            context.insert(model)
        }

        try context.saveChanges()
    }

    private static func clearAll(context: ModelContext) throws {
        try context.fetch(FetchDescriptor<PaymentRecord>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<Receivable>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<SaleItem>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<Sale>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<ProductionBatch>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<RecipeIngredient>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<Recipe>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<SupplyMovement>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<SupplyItem>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<Customer>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<Flavor>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<Expense>()).forEach { context.delete($0) }
        try context.saveChanges()
    }
}
