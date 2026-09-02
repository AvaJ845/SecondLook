import AppIntents
import SwiftUI
import WidgetKit

/// Control Center / Lock Screen / Action Button control (iOS 18). One tap opens
/// SecondLook and offers to check whatever you've copied.
struct CheckClipboardControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.avaresearch.secondlook.control.checkClipboard") {
            ControlWidgetButton(action: OpenToCheckIntent()) {
                Label("Check clipboard", systemImage: "text.viewfinder")
            }
        }
        .displayName("Check Clipboard")
        .description("Run SecondLook on a job message you've copied.")
    }
}
