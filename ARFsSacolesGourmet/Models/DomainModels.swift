import Foundation
import SwiftData

enum SupplyCategory: String, Codable, CaseIterable, Identifiable {
    case dairy = "Laticínios"
    case fruit = "Polpas e Frutas"
    case sweets = "Doces e Chocolates"
    case packaging = "Embalagens"
    case utensils = "Utensílios"
    case other = "Outros"

    var id: String { rawValue }
}

enum UnitDimension: String, Codable {
    case weight
    case volume
    case count
}

enum UnitOfMeasure: String, Codable, CaseIterable, Identifiable {
    case kilogram = "kg"
    case gram = "g"
    case liter = "litro"
    case milliliter = "ml"
    case unit = "unidade"
    case package = "pacote"

    var id: String { rawValue }

    var label: String { rawValue }

    var dimension: UnitDimension {
        switch self {
        case .kilogram, .gram:
            return .weight
        case .liter, .milliliter:
            return .volume
        case .unit, .package:
            return .count
        }
    }

    var baseFactor: Double {
        switch self {
        case .kilogram:
            return 1000
        case .gram:
            return 1
        case .liter:
            return 1000
        case .milliliter:
            return 1
        case .unit, .package:
            return 1
        }
    }

    func toBase(_ quantity: Double) -> Double {
        quantity * baseFactor
    }

    func fromBase(_ quantity: Double) -> Double {
        quantity / baseFactor
    }

    func isCompatible(with other: UnitOfMeasure) -> Bool {
        dimension == other.dimension
    }
}

enum SupplyMovementType: String, Codable, CaseIterable, Identifiable {
    case stockIn = "Entrada"
    case stockOut = "Saída"
    case adjustment = "Ajuste"
    case production = "Consumo em Produção"

    var id: String { rawValue }
}

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case pix = "Pix"
    case cash = "Dinheiro"
    case card = "Cartão"
    case pending = "Fiado / Pendente"
    case partial = "Pagamento Parcial"

    var id: String { rawValue }
}

enum SaleOrigin: String, Codable, CaseIterable, Identifiable {
    case manual = "Venda Manual"
    case catalog = "Pedido pelo Catálogo"

    var id: String { rawValue }
}

enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case materialPurchase = "Compra de Material"
    case ingredients = "Compra de Ingredientes"
    case packaging = "Embalagens"
    case transport = "Transporte"
    case energy = "Energia"
    case maintenance = "Manutenção"
    case gas = "Gás"
    case marketing = "Divulgação"
    case other = "Outros"

    var id: String { rawValue }
}

@Model
final class Flavor {
    @Attribute(.unique) var id: UUID
    var name: String
    var flavorDescription: String
    var salePrice: Double
    var estimatedUnitCost: Double
    var stockQuantity: Int
    var minimumStock: Int
    var isActive: Bool
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Recipe.flavor) var recipes: [Recipe] = []
    @Relationship(inverse: \ProductionBatch.flavor) var productionBatches: [ProductionBatch] = []
    @Relationship(inverse: \SaleItem.flavor) var saleItems: [SaleItem] = []

    init(
        id: UUID = UUID(),
        name: String,
        flavorDescription: String = "",
        salePrice: Double,
        estimatedUnitCost: Double = 0,
        stockQuantity: Int = 0,
        minimumStock: Int = 10,
        isActive: Bool = true,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.flavorDescription = flavorDescription
        self.salePrice = salePrice
        self.estimatedUnitCost = estimatedUnitCost
        self.stockQuantity = stockQuantity
        self.minimumStock = minimumStock
        self.isActive = isActive
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var estimatedMarginValue: Double {
        salePrice - estimatedUnitCost
    }

    var estimatedMarginPercent: Double {
        guard salePrice > 0 else { return 0 }
        return estimatedMarginValue / salePrice
    }

    var isLowStock: Bool {
        stockQuantity <= minimumStock
    }

    var defaultRecipe: Recipe? {
        recipes.first(where: { $0.isDefault }) ?? recipes.first
    }
}

@Model
final class SupplyItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: SupplyCategory
    var unit: UnitOfMeasure
    var currentStock: Double
    var minimumStock: Double
    var purchaseCost: Double
    var supplier: String
    var lastPurchaseDate: Date?
    var notes: String
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \SupplyMovement.supplyItem) var movements: [SupplyMovement] = []
    @Relationship(inverse: \RecipeIngredient.supplyItem) var recipeIngredients: [RecipeIngredient] = []

    init(
        id: UUID = UUID(),
        name: String,
        category: SupplyCategory,
        unit: UnitOfMeasure,
        currentStock: Double = 0,
        minimumStock: Double = 0,
        purchaseCost: Double = 0,
        supplier: String = "",
        lastPurchaseDate: Date? = nil,
        notes: String = "",
        isActive: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.unit = unit
        self.currentStock = currentStock
        self.minimumStock = minimumStock
        self.purchaseCost = purchaseCost
        self.supplier = supplier
        self.lastPurchaseDate = lastPurchaseDate
        self.notes = notes
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isLowStock: Bool {
        currentStock <= minimumStock
    }

    var currentStockBase: Double {
        unit.toBase(currentStock)
    }

    var minimumStockBase: Double {
        unit.toBase(minimumStock)
    }
}

@Model
final class SupplyMovement {
    @Attribute(.unique) var id: UUID
    var movementDate: Date
    var type: SupplyMovementType
    var quantity: Double
    var previousQuantity: Double
    var newQuantity: Double
    var notes: String
    var unitCostSnapshot: Double
    var supplyItem: SupplyItem?

    init(
        id: UUID = UUID(),
        movementDate: Date = .now,
        type: SupplyMovementType,
        quantity: Double,
        previousQuantity: Double,
        newQuantity: Double,
        notes: String = "",
        unitCostSnapshot: Double = 0,
        supplyItem: SupplyItem? = nil
    ) {
        self.id = id
        self.movementDate = movementDate
        self.type = type
        self.quantity = quantity
        self.previousQuantity = previousQuantity
        self.newQuantity = newQuantity
        self.notes = notes
        self.unitCostSnapshot = unitCostSnapshot
        self.supplyItem = supplyItem
    }
}

@Model
final class Recipe {
    @Attribute(.unique) var id: UUID
    var title: String
    var yieldQuantity: Int
    var notes: String
    var isDefault: Bool
    var createdAt: Date
    var updatedAt: Date
    var flavor: Flavor?

    @Relationship(deleteRule: .cascade, inverse: \RecipeIngredient.recipe) var ingredients: [RecipeIngredient] = []
    @Relationship(inverse: \ProductionBatch.recipe) var productionBatches: [ProductionBatch] = []

    init(
        id: UUID = UUID(),
        title: String,
        yieldQuantity: Int,
        notes: String = "",
        isDefault: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        flavor: Flavor? = nil
    ) {
        self.id = id
        self.title = title
        self.yieldQuantity = yieldQuantity
        self.notes = notes
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.flavor = flavor
    }
}

@Model
final class RecipeIngredient {
    @Attribute(.unique) var id: UUID
    var quantityUsed: Double
    var usageUnit: UnitOfMeasure
    var notes: String
    var recipe: Recipe?
    var supplyItem: SupplyItem?

    init(
        id: UUID = UUID(),
        quantityUsed: Double,
        usageUnit: UnitOfMeasure,
        notes: String = "",
        recipe: Recipe? = nil,
        supplyItem: SupplyItem? = nil
    ) {
        self.id = id
        self.quantityUsed = quantityUsed
        self.usageUnit = usageUnit
        self.notes = notes
        self.recipe = recipe
        self.supplyItem = supplyItem
    }
}

@Model
final class ProductionBatch {
    @Attribute(.unique) var id: UUID
    var productionDate: Date
    var quantityProduced: Int
    var totalCost: Double
    var unitCost: Double
    var notes: String
    var flavor: Flavor?
    var recipe: Recipe?

    init(
        id: UUID = UUID(),
        productionDate: Date = .now,
        quantityProduced: Int,
        totalCost: Double,
        unitCost: Double,
        notes: String = "",
        flavor: Flavor? = nil,
        recipe: Recipe? = nil
    ) {
        self.id = id
        self.productionDate = productionDate
        self.quantityProduced = quantityProduced
        self.totalCost = totalCost
        self.unitCost = unitCost
        self.notes = notes
        self.flavor = flavor
        self.recipe = recipe
    }
}

@Model
final class Customer {
    @Attribute(.unique) var id: UUID
    var name: String
    var phone: String
    var socialHandle: String
    var address: String
    var neighborhood: String
    var notes: String
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(inverse: \Sale.customer) var sales: [Sale] = []
    @Relationship(inverse: \Receivable.customer) var receivables: [Receivable] = []
    @Relationship(inverse: \PaymentRecord.customer) var paymentRecords: [PaymentRecord] = []

    init(
        id: UUID = UUID(),
        name: String,
        phone: String = "",
        socialHandle: String = "",
        address: String = "",
        neighborhood: String = "",
        notes: String = "",
        isActive: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.phone = phone
        self.socialHandle = socialHandle
        self.address = address
        self.neighborhood = neighborhood
        self.notes = notes
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var totalBought: Double {
        sales.reduce(0) { $0 + $1.totalAmount }
    }

    var openBalance: Double {
        receivables.reduce(0) { $0 + $1.balance }
    }
}

@Model
final class Sale {
    @Attribute(.unique) var id: UUID
    var saleDate: Date
    var customerNameSnapshot: String
    var discountAmount: Double
    var subtotalAmount: Double
    var totalAmount: Double
    var notes: String
    var paymentMethod: PaymentMethod
    var origin: SaleOrigin
    var customer: Customer?

    @Relationship(deleteRule: .cascade, inverse: \SaleItem.sale) var items: [SaleItem] = []
    @Relationship(deleteRule: .cascade, inverse: \PaymentRecord.sale) var paymentRecords: [PaymentRecord] = []
    var receivable: Receivable?

    init(
        id: UUID = UUID(),
        saleDate: Date = .now,
        customerNameSnapshot: String,
        discountAmount: Double = 0,
        subtotalAmount: Double,
        totalAmount: Double,
        notes: String = "",
        paymentMethod: PaymentMethod,
        origin: SaleOrigin = .manual,
        customer: Customer? = nil
    ) {
        self.id = id
        self.saleDate = saleDate
        self.customerNameSnapshot = customerNameSnapshot
        self.discountAmount = discountAmount
        self.subtotalAmount = subtotalAmount
        self.totalAmount = totalAmount
        self.notes = notes
        self.paymentMethod = paymentMethod
        self.origin = origin
        self.customer = customer
    }

    var amountReceived: Double {
        paymentRecords.reduce(0) { $0 + $1.amount }
    }

    var amountOpen: Double {
        max(totalAmount - amountReceived, 0)
    }

    var paymentStatusLabel: String {
        if amountOpen == 0 {
            return "Pago"
        }
        if amountReceived > 0 {
            return "Parcial"
        }
        return "Pendente"
    }
}

@Model
final class SaleItem {
    @Attribute(.unique) var id: UUID
    var quantity: Int
    var unitPrice: Double
    var unitCostSnapshot: Double
    var sale: Sale?
    var flavor: Flavor?

    init(
        id: UUID = UUID(),
        quantity: Int,
        unitPrice: Double,
        unitCostSnapshot: Double,
        sale: Sale? = nil,
        flavor: Flavor? = nil
    ) {
        self.id = id
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.unitCostSnapshot = unitCostSnapshot
        self.sale = sale
        self.flavor = flavor
    }

    var lineTotal: Double {
        Double(quantity) * unitPrice
    }

    var lineCost: Double {
        Double(quantity) * unitCostSnapshot
    }

    var lineProfit: Double {
        lineTotal - lineCost
    }
}

@Model
final class Receivable {
    @Attribute(.unique) var id: UUID
    var totalAmount: Double
    var dueDate: Date
    var notes: String
    var createdAt: Date
    var sale: Sale?
    var customer: Customer?

    @Relationship(deleteRule: .cascade, inverse: \PaymentRecord.receivable) var paymentRecords: [PaymentRecord] = []

    init(
        id: UUID = UUID(),
        totalAmount: Double,
        dueDate: Date,
        notes: String = "",
        createdAt: Date = .now,
        sale: Sale? = nil,
        customer: Customer? = nil
    ) {
        self.id = id
        self.totalAmount = totalAmount
        self.dueDate = dueDate
        self.notes = notes
        self.createdAt = createdAt
        self.sale = sale
        self.customer = customer
    }

    var amountReceived: Double {
        paymentRecords.reduce(0) { $0 + $1.amount }
    }

    var balance: Double {
        max(totalAmount - amountReceived, 0)
    }

    var statusLabel: String {
        if balance == 0 {
            return "Pago"
        }
        if dueDate < .now.startOfDayInBrazil {
            return "Vencido"
        }
        if amountReceived > 0 {
            return "Parcialmente Pago"
        }
        return "Pendente"
    }
}

@Model
final class PaymentRecord {
    @Attribute(.unique) var id: UUID
    var amount: Double
    var paymentDate: Date
    var method: PaymentMethod
    var notes: String
    var sale: Sale?
    var receivable: Receivable?
    var customer: Customer?

    init(
        id: UUID = UUID(),
        amount: Double,
        paymentDate: Date = .now,
        method: PaymentMethod,
        notes: String = "",
        sale: Sale? = nil,
        receivable: Receivable? = nil,
        customer: Customer? = nil
    ) {
        self.id = id
        self.amount = amount
        self.paymentDate = paymentDate
        self.method = method
        self.notes = notes
        self.sale = sale
        self.receivable = receivable
        self.customer = customer
    }
}

@Model
final class Expense {
    @Attribute(.unique) var id: UUID
    var title: String
    var category: ExpenseCategory
    var supplier: String
    var amount: Double
    var launchDate: Date
    var dueDate: Date
    var paymentMethod: PaymentMethod?
    var notes: String
    var paidAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        category: ExpenseCategory,
        supplier: String = "",
        amount: Double,
        launchDate: Date = .now,
        dueDate: Date,
        paymentMethod: PaymentMethod? = nil,
        notes: String = "",
        paidAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.supplier = supplier
        self.amount = amount
        self.launchDate = launchDate
        self.dueDate = dueDate
        self.paymentMethod = paymentMethod
        self.notes = notes
        self.paidAt = paidAt
    }

    var isPaid: Bool {
        paidAt != nil
    }

    var statusLabel: String {
        if isPaid {
            return "Pago"
        }
        if dueDate < .now.startOfDayInBrazil {
            return "Vencido"
        }
        return "Pendente"
    }
}
