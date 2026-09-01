import SwiftUI

/// Legal/CCO-mandated framing. SecondLook flags patterns; it does not accuse
/// companies or guarantee safety.
struct DisclaimerFooter: View {
    var body: some View {
        Text("SecondLook points out patterns commonly seen in job scams. It can't confirm whether any message, company, or person is legitimate, and a clean result isn't a guarantee. When money, documents, or personal numbers are involved, verify the employer independently. To report a job scam in the U.S., visit reportfraud.ftc.gov.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
