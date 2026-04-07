import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \Flavor.name) private var flavors: [Flavor]
    @Query(sort: \SupplyItem.name) private var supplies: [SupplyItem]
    @Query(sort: \Sale.saleDate, order: .reverse) private var sales: [Sale]
    @Query(sort: \PaymentRecord.paymentDate, order: .reverse) private var payments: [PaymentRecord]
    @Query(sort: \Receivable.dueDate) private var receivables: [Receivable]
    @Query(sort: \Expense.dueDate) private var expenses: [Expense]

    private var snapshot: DashboardMetricSnapshot {
        DashboardService.buildSnapshot(
            flavors: flavors,
            supplies: supplies,
            sales: sales,
            payments: payments,
            receivables: receivables,
            expenses: expenses
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroHeader

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    MetricCard(title: "Faturamento do Dia", value: snapshot.revenueToday.brlCurrency, subtitle: "vendas registradas hoje", color: AppTheme.accent, systemImage: "sun.max")
                    MetricCard(title: "Faturamento do Mês", value: snapshot.revenueMonth.brlCurrency, subtitle: "competência mensal", color: AppTheme.highlight, systemImage: "calendar")
                    MetricCard(title: "Total Recebido", value: snapshot.receivedTotal.brlCurrency, subtitle: "soma dos recebimentos", color: AppTheme.success, systemImage: "arrow.down.circle")
                    MetricCard(title: "Total a Receber", value: snapshot.receivableTotal.brlCurrency, subtitle: "pendências em aberto", color: AppTheme.warning, systemImage: "clock.arrow.circlepath")
                    MetricCard(title: "Total a Pagar", value: snapshot.payableTotal.brlCurrency, subtitle: "despesas ainda abertas", color: AppTheme.danger, systemImage: "arrow.up.circle")
                    MetricCard(title: "Lucro Estimado do Mês", value: snapshot.estimatedProfitMonth.brlCurrency, subtitle: "faturamento - CPV - despesas", color: AppTheme.brandBrown, systemImage: "chart.line.uptrend.xyaxis")
                }

                PremiumCard(title: "Vendas por Sabor") {
                    if snapshot.salesByFlavor.isEmpty {
                        emptyMessage("Ainda não há vendas suficientes para exibir o gráfico.")
                    } else {
                        Chart(snapshot.salesByFlavor) { row in
                            BarMark(
                                x: .value("Quantidade", row.quantity),
                                y: .value("Sabor", row.name)
                            )
                            .foregroundStyle(AppTheme.accent.gradient)
                        }
                        .frame(height: 220)
                    }
                }

                PremiumCard(title: "Alertas Operacionais") {
                    VStack(alignment: .leading, spacing: 12) {
                        alertLine(title: "Sabores com estoque baixo", value: "\(snapshot.lowStockFlavors.count)")
                        alertLine(title: "Insumos com estoque baixo", value: "\(snapshot.lowStockSupplies.count)")
                        alertLine(title: "Contas a receber vencidas", value: "\(snapshot.overdueReceivables.count)")
                        alertLine(title: "Contas a pagar vencidas", value: "\(snapshot.overdueExpenses.count)")
                    }
                }

                PremiumCard(title: "Sabores com Estoque Baixo") {
                    if snapshot.lowStockFlavors.isEmpty {
                        emptyMessage("Nenhum sabor com estoque crítico no momento.")
                    } else {
                        ForEach(snapshot.lowStockFlavors.prefix(5), id: \.id) { flavor in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(flavor.name)
                                        .font(.headline)
                                    Text("Atual: \(flavor.stockQuantity.brInteger) | Mínimo: \(flavor.minimumStock.brInteger)")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer()
                                StatusPill(text: "Baixo", color: AppTheme.warning)
                            }
                            if flavor.id != snapshot.lowStockFlavors.prefix(5).last?.id {
                                Divider()
                            }
                        }
                    }
                }

                PremiumCard(title: "Resumo Rápido das Vendas") {
                    if snapshot.recentSales.isEmpty {
                        emptyMessage("Nenhuma venda registrada ainda.")
                    } else {
                        ForEach(snapshot.recentSales, id: \.id) { sale in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(sale.customerNameSnapshot)
                                        .font(.headline)
                                    Spacer()
                                    Text(sale.totalAmount.brlCurrency)
                                        .font(.headline)
                                }
                                Text("\(sale.saleDate.brDate) • \(sale.paymentStatusLabel) • \(sale.origin.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            if sale.id != snapshot.recentSales.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .brandPlainBackground()
        .navigationTitle("Dashboard")
    }

    private var heroHeader: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    Image("BrandLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 78, height: 78)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("ARF's Sacolés Gourmet")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("Controle completo da operação em um único lugar: produção, vendas, estoque, clientes e financeiro.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                HStack(spacing: 10) {
                    StatusPill(text: "Uso Offline", color: AppTheme.success)
                    StatusPill(text: "Dados Locais", color: AppTheme.brandBrown)
                    StatusPill(text: "Gestão Diária", color: AppTheme.highlight)
                }
            }
        }
    }

    private func alertLine(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Text(value)
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private func emptyMessage(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(AppTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
