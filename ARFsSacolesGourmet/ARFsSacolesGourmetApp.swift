import SwiftUI
import SwiftData
import UIKit

@main
struct ARFsSacolesGourmetApp: App {
    private let container: ModelContainer

    init() {
        do {
            Self.configureAppearance()
            let schema = Schema([
                Flavor.self,
                SupplyItem.self,
                SupplyMovement.self,
                Recipe.self,
                RecipeIngredient.self,
                ProductionBatch.self,
                Customer.self,
                Sale.self,
                SaleItem.self,
                Receivable.self,
                PaymentRecord.self,
                Expense.self
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [configuration])
            try SampleDataSeeder.seedIfNeeded(in: container.mainContext)
        } catch {
            fatalError("Falha ao inicializar o banco local: \(error.localizedDescription)")
        }
    }

    private static func configureAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(red: 0.97, green: 0.95, blue: 0.92, alpha: 1)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(red: 0.18, green: 0.14, blue: 0.12, alpha: 1)]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(red: 0.18, green: 0.14, blue: 0.12, alpha: 1)]
        navAppearance.shadowColor = UIColor(red: 0.82, green: 0.75, blue: 0.67, alpha: 0.5)
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(red: 0.12, green: 0.36, blue: 0.34, alpha: 1)

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(red: 0.97, green: 0.95, blue: 0.92, alpha: 0.98)
        tabAppearance.shadowColor = UIColor(red: 0.82, green: 0.75, blue: 0.67, alpha: 0.45)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }

    var body: some Scene {
        WindowGroup {
            RootContainerView()
                .modelContainer(container)
                .preferredColorScheme(.light)
                .tint(AppTheme.accent)
        }
    }
}
