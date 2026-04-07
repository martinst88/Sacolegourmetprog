import SwiftUI

struct RootContainerView: View {
    @State private var showSplash = true
    @State private var isAuthenticated = false

    var body: some View {
        Group {
            if showSplash {
                SplashView()
            } else if isAuthenticated {
                MainTabView()
            } else {
                LocalAccessView(isAuthenticated: $isAuthenticated)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSplash)
        .task {
            try? await Task.sleep(for: .seconds(1.6))
            showSplash = false
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            AppTheme.heroGradient
                .ignoresSafeArea()

            Circle()
                .fill(AppTheme.logoGlow.opacity(0.82))
                .blur(radius: 28)
                .frame(width: 320, height: 320)

            VStack(spacing: 18) {
                Image("BrandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 290)
                    .shadow(color: AppTheme.brandBrown.opacity(0.18), radius: 24, x: 0, y: 14)

                Text("Gestão completa da operação, vendas e financeiro")
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 28)
            }
            .padding(32)
        }
    }
}

struct LocalAccessView: View {
    @Binding var isAuthenticated: Bool
    @AppStorage("arf_requires_local_pin") private var requiresPIN = false
    @AppStorage("arf_local_pin") private var savedPIN = ""

    @State private var pinInput = ""
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            AppTheme.screenGradient
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image("BrandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180)
                    .shadow(color: AppTheme.brandBrown.opacity(0.12), radius: 20, x: 0, y: 10)

                PremiumCard {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Acesso Local")
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("Aplicativo nativo para controlar sabores, produção, vendas, clientes e financeiro do negócio.")
                            .foregroundStyle(AppTheme.textSecondary)

                        if requiresPIN {
                            SecureField("Digite o PIN local", text: $pinInput)
                                .textContentType(.oneTimeCode)
                                .keyboardType(.numberPad)
                                .padding(14)
                                .background(AppTheme.secondaryBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.danger)
                        }

                        Button {
                            validateAccess()
                        } label: {
                            Text("Entrar no App")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private func validateAccess() {
        guard requiresPIN else {
            isAuthenticated = true
            return
        }

        if pinInput == savedPIN {
            errorMessage = ""
            isAuthenticated = true
        } else {
            errorMessage = "PIN inválido. Tente novamente."
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("Dashboard", systemImage: "rectangle.grid.2x2")
            }

            NavigationStack {
                OperationsHomeView()
            }
            .tabItem {
                Label("Operação", systemImage: "shippingbox")
            }

            NavigationStack {
                SalesHomeView()
            }
            .tabItem {
                Label("Vendas", systemImage: "cart")
            }

            NavigationStack {
                FinanceHomeView()
            }
            .tabItem {
                Label("Financeiro", systemImage: "chart.line.uptrend.xyaxis")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Config.", systemImage: "gearshape")
            }
        }
        .toolbarBackground(AppTheme.secondaryBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.light, for: .tabBar)
    }
}
