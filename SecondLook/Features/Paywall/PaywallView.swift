import SwiftUI
import StoreKit

/// SecondLook Plus. Prices, periods and trial come from StoreKit `Product`
/// objects — never hard-coded. Basic safety checking is never gated; this only
/// unlocks depth and volume.
struct PaywallView: View {
    /// Context line shown at the top — lets the same screen serve the post-first-check
    /// upsell and the "you're out of Deep AI Checks" moment.
    var reason: Reason = .general

    enum Reason {
        case general
        case afterFirstCheck
        case deepCheckLimit

        var title: String {
            switch self {
            case .general: return "SecondLook Plus"
            case .afterFirstCheck: return "Take a deeper second look."
            case .deepCheckLimit: return "You're out of Deep AI Checks this month."
            }
        }

        var subtitle: String {
            switch self {
            case .general:
                return "More AI-assisted context when something doesn't feel right."
            case .afterFirstCheck:
                return "Plus gives you deeper screenshot analysis and more AI-assisted context when something doesn't feel right."
            case .deepCheckLimit:
                return "Plus includes 20 Deep AI Checks a month. Your standard on-device checks are always unlimited and free."
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subs
    @Environment(Entitlements.self) private var entitlements

    @State private var selected: Plan = .yearly
    @State private var working = false
    @State private var message: String?

    enum Plan { case yearly, monthly }

    private let termsURL = URL(string: "https://avaj845.github.io/SecondLook/terms.html")!
    private let privacyURL = URL(string: "https://avaj845.github.io/SecondLook/privacy.html")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    benefits

                    if subs.loadState == .loading {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
                    } else if subs.monthly == nil && subs.yearly == nil {
                        unavailable
                    } else {
                        planCards
                        purchaseButton
                        afterTrialLine
                    }

                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(Palette.color(for: .serious))
                    }

                    footer
                }
                .padding(20)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.brandCanvas)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark").font(.subheadline.weight(.semibold)) }
                        .tint(Palette.brandSecondaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Restore") { Task { await restore() } }
                        .font(.subheadline)
                        .disabled(working)
                }
            }
        }
        .task { if subs.loadState == .idle { await subs.loadProducts() } }
        .onChange(of: entitlements.isPlus) { _, isPlus in if isPlus { dismiss() } }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(reason.title)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(Palette.brandNavy)
            Text(reason.subtitle)
                .font(.subheadline)
                .foregroundStyle(Palette.brandSecondaryText)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 10) {
            benefit("20 Deep AI Checks a month", "Free includes 2.")
            benefit("Deeper screenshot & context analysis", "More detail on what the model sees.")
            benefit("Full, unlimited saved history", "Free keeps your recent checks.")
            benefit("Priority AI processing", nil)
        }
    }

    private func benefit(_ title: String, _ detail: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.brandTeal)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(Palette.brandNavy)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(Palette.brandSecondaryText)
                }
            }
        }
    }

    private var planCards: some View {
        VStack(spacing: 12) {
            if let yearly = subs.yearly {
                planCard(
                    plan: .yearly,
                    name: "Yearly",
                    price: yearly.displayPrice,
                    caption: subs.yearlyPerMonthText.map { "About \($0)" } ?? "Best value",
                    badge: "Best value",
                    trial: subs.introOfferText(for: yearly)
                )
            }
            if let monthly = subs.monthly {
                planCard(
                    plan: .monthly,
                    name: "Monthly",
                    price: "\(monthly.displayPrice)/mo",
                    caption: "Billed monthly",
                    badge: nil,
                    trial: subs.introOfferText(for: monthly)
                )
            }
        }
    }

    private func planCard(plan: Plan, name: String, price: String, caption: String, badge: String?, trial: String?) -> some View {
        let isSelected = selected == plan
        return Button {
            selected = plan
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Palette.brandTeal : Palette.brandSecondaryText)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(name).font(.headline).foregroundStyle(Palette.brandNavy)
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Palette.brandCoral, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    Text(caption).font(.caption).foregroundStyle(Palette.brandSecondaryText)
                    if let trial {
                        Text(trial).font(.caption.weight(.semibold)).foregroundStyle(Palette.brandTeal)
                    }
                }
                Spacer()
                Text(price).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.brandNavy)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Palette.brandTeal : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var purchaseButton: some View {
        Button {
            Task { await buy() }
        } label: {
            HStack {
                if working { ProgressView().tint(.white) }
                Text(ctaTitle).font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Palette.brandTeal)
        .disabled(working || selectedProduct == nil)
    }

    private var ctaTitle: String {
        if let product = selectedProduct, subs.introOfferText(for: product) != nil {
            return "Start Free Trial"
        }
        return "Continue"
    }

    private var afterTrialLine: some View {
        Group {
            if let product = selectedProduct, let trial = subs.introOfferText(for: product) {
                Text("Your \(trial) starts today. After it ends, \(product.displayPrice)\(selected == .monthly ? "/month" : "/year") is billed to your Apple ID until you cancel. Cancel anytime in Settings.")
            } else if let product = selectedProduct {
                Text("\(product.displayPrice)\(selected == .monthly ? "/month" : "/year") is billed to your Apple ID and auto-renews until you cancel. Cancel anytime in Settings.")
            }
        }
        .font(.caption2)
        .foregroundStyle(Palette.brandSecondaryText)
    }

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Plans couldn't be loaded")
                .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.brandNavy)
            Text("Check your connection and try again. Your standard on-device checks work regardless.")
                .font(.caption).foregroundStyle(Palette.brandSecondaryText)
            Button("Retry") { Task { await subs.loadProducts() } }.font(.subheadline)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(uiColor: .secondarySystemGroupedBackground)))
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Text("Your standard on-device checks are always free and unlimited. Plus never gates basic safety.")
                .font(.caption2)
                .foregroundStyle(Palette.brandSecondaryText)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Link("Terms", destination: termsURL)
                Link("Privacy Policy", destination: privacyURL)
            }
            .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: Actions

    private var selectedProduct: Product? {
        selected == .yearly ? subs.yearly : subs.monthly
    }

    private func buy() async {
        guard let product = selectedProduct else { return }
        working = true; message = nil
        defer { working = false }
        switch await subs.purchase(product) {
        case .success:
            dismiss()
        case .pending:
            message = "Your purchase is pending approval. SecondLook Plus will unlock once it's approved."
        case .userCancelled:
            break
        case .failed(let why):
            message = why
        }
    }

    private func restore() async {
        working = true; message = nil
        defer { working = false }
        switch await subs.restore() {
        case .success: dismiss()
        case .failed(let why): message = why
        default: break
        }
    }
}

#Preview {
    PaywallView(reason: .afterFirstCheck)
        .environment(SubscriptionManager(entitlements: Entitlements()))
        .environment(Entitlements())
}
