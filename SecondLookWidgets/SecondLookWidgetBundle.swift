import WidgetKit
import SwiftUI

@main
struct SecondLookWidgetBundle: WidgetBundle {
    var body: some Widget {
        StatsWidget()
        CheckClipboardControl()
    }
}
