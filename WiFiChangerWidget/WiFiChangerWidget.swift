import WidgetKit
import SwiftUI

struct SwitchEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct SwitchProvider: TimelineProvider {
    func placeholder(in context: Context) -> SwitchEntry {
        SwitchEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SwitchEntry) -> Void) {
        let s = SharedStore.loadSnapshot()
        completion(SwitchEntry(date: Date(), snapshot: s ?? (context.isPreview ? .placeholder : nil)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SwitchEntry>) -> Void) {
        let entry = SwitchEntry(date: Date(), snapshot: SharedStore.loadSnapshot())
        // 切り替えるたびにアプリから更新する。念のため1時間ごとにも読み直す
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600))))
    }
}

struct SwitchWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SwitchEntry

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if isAccessory {
                    Color.clear
                } else {
                    Color("WidgetBackground")
                }
            }
    }

    private var isAccessory: Bool {
        family == .accessoryCircular || family == .accessoryRectangular || family == .accessoryInline
    }

    @ViewBuilder
    private var content: some View {
        if let s = entry.snapshot, !s.configured.isEmpty {
            switch family {
            case .systemMedium:
                MediumSwitchView(s: s)
            case .accessoryCircular:
                CircularSwitchView(s: s).widgetURL(Links.toggle)
            case .accessoryRectangular:
                RectangularSwitchView(s: s).widgetURL(Links.toggle)
            case .accessoryInline:
                InlineSwitchView(s: s).widgetURL(Links.toggle)
            default:
                SmallSwitchView(s: s).widgetURL(Links.toggle)
            }
        } else {
            EmptyWidgetView(family: family).widgetURL(Links.open)
        }
    }
}

struct SwitchWidget: Widget {
    let kind = "WiFiSwitch"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SwitchProvider()) { entry in
            SwitchWidgetView(entry: entry)
        }
        .configurationDisplayName("Wi-Fi切り替え")
        .description("タップで2つのWi-Fiを切り替えます。中サイズは押したほうに接続します。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct WiFiChangerWidgets: WidgetBundle {
    var body: some Widget {
        SwitchWidget()
    }
}
