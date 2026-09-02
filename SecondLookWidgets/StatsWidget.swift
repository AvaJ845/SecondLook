import WidgetKit
import SwiftUI

// Brand tokens, inlined so the widget target has no dependency on the app's Theme.
private enum W {
    static let navy = Color(red: 0x17 / 255, green: 0x20 / 255, blue: 0x33 / 255)
    static let teal = Color(red: 0x39 / 255, green: 0xB7 / 255, blue: 0xA5 / 255)
    static let coral = Color(red: 0xF2 / 255, green: 0x8B / 255, blue: 0x7A / 255)
    static let deepLink = URL(string: "secondlook://check")!
}

struct StatsEntry: TimelineEntry {
    let date: Date
    let counters: UsageCounters
}

struct StatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatsEntry {
        StatsEntry(date: .now, counters: UsageCounters(monthLabel: "September", checked: 12, flagged: 4))
    }
    func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> Void) {
        completion(StatsEntry(date: .now, counters: UsageStats.current()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> Void) {
        let entry = StatsEntry(date: .now, counters: UsageStats.current())
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct StatsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.avaresearch.secondlook.widget.stats", provider: StatsProvider()) { entry in
            StatsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(W.deepLink)
        }
        .configurationDisplayName("This month")
        .description("Messages you've checked and how many were flagged.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

struct StatsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StatsEntry

    private var c: UsageCounters { entry.counters }
    private var isEmpty: Bool { c.checked == 0 }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(isEmpty ? "SecondLook — check a message" : "SecondLook: \(c.checked) checked, \(c.flagged) flagged")
        case .accessoryCircular:
            Gauge(value: Double(c.flagged), in: 0...Double(max(c.checked, 1))) {
                Image(systemName: "checkmark.shield")
            } currentValueLabel: {
                Text("\(c.checked)")
            }
            .gaugeStyle(.accessoryCircular)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("SecondLook", systemImage: "checkmark.shield.fill").font(.caption2.weight(.semibold))
                if isEmpty {
                    Text("Check a job message")
                } else {
                    Text("\(c.checked) checked this month")
                    Text("\(c.flagged) flagged").foregroundStyle(.secondary)
                }
            }
        default:
            small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.shield.fill").foregroundStyle(W.teal)
                Text("SecondLook").font(.footnote.weight(.semibold)).foregroundStyle(W.navy)
                Spacer()
            }

            if isEmpty {
                Spacer(minLength: 0)
                Text("Check a job message before you reply.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(W.navy)
                Spacer(minLength: 0)
                Text("Tap to start").font(.caption2).foregroundStyle(.secondary)
            } else {
                Spacer(minLength: 0)
                Text("\(c.checked)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(W.navy)
                Text("checked in \(c.monthLabel)")
                    .font(.caption).foregroundStyle(.secondary)
                if c.flagged > 0 {
                    Text("\(c.flagged) flagged")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(W.coral)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
