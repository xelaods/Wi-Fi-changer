import SwiftUI
import WidgetKit

/// 設定アプリのような角丸のアイコン
struct IconTile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 29

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
            .fill(color.gradient)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.55, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

/// 丸いアイコン（コントロールセンター風）
struct IconCircle: View {
    let network: WiFiNetwork
    var active: Bool
    var size: CGFloat = 34

    var body: some View {
        Circle()
            .fill(active ? AnyShapeStyle(Color.white) : AnyShapeStyle(network.tint.color.gradient))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: network.symbol)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(active ? network.tint.color : .white)
            }
            .widgetAccentable()
    }
}

// MARK: 小

struct SmallSwitchView: View {
    let s: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                if let cur = s.current {
                    IconCircle(network: cur, active: false, size: 40)
                } else {
                    Circle().fill(Color.secondary.opacity(0.25))
                        .frame(width: 40, height: 40)
                        .overlay { Image(systemName: "wifi.slash").font(.system(size: 18, weight: .semibold)).foregroundStyle(.secondary) }
                }
                Spacer()
                Image(systemName: "wifi")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Text(s.current == nil ? "未接続" : "接続中")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(s.current?.displayName ?? "Wi-Fi")
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 8)
            if let next = s.next, next.id != s.currentID {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.arrow.right")
                    Text(next.displayName).lineLimit(1)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(next.tint.color.gradient))
                .widgetAccentable()
            }
        }
    }
}

// MARK: 中

struct MediumSwitchView: View {
    let s: WidgetSnapshot

    var body: some View {
        HStack(spacing: 10) {
            ForEach(s.networks) { n in
                Link(destination: n.isConfigured ? Links.connect(n.id) : Links.open) {
                    MediumTile(network: n, active: n.id == s.currentID)
                }
            }
        }
    }
}

struct MediumTile: View {
    let network: WiFiNetwork
    let active: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                IconCircle(network: network, active: active, size: 36)
                Spacer()
                if active {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.white)
                }
            }
            Spacer(minLength: 4)
            Text(network.isConfigured ? network.displayName : "未設定")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(status)
                .font(.caption)
                .lineLimit(1)
                .opacity(active ? 0.85 : 1)
                .foregroundStyle(active ? AnyShapeStyle(Color.white) : AnyShapeStyle(.secondary))
        }
        .foregroundStyle(active ? Color.white : Color.primary)
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(active ? AnyShapeStyle(network.tint.color.gradient) : AnyShapeStyle(Color.secondary.opacity(0.14)))
        )
    }

    private var status: String {
        if !network.isConfigured { return "アプリで設定" }
        return active ? "接続中" : "タップで接続"
    }
}

// MARK: ロック画面

struct CircularSwitchView: View {
    let s: WidgetSnapshot

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: s.current?.symbol ?? "wifi")
                    .font(.system(size: 20, weight: .semibold))
                Text(s.current?.displayName ?? "Wi-Fi")
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 6)
            }
        }
    }
}

struct RectangularSwitchView: View {
    let s: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label("Wi-Fi", systemImage: "wifi")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(s.current?.displayName ?? "未接続")
                .font(.headline)
                .lineLimit(1)
                .widgetAccentable()
            if let next = s.next, next.id != s.currentID {
                Label(next.displayName, systemImage: "arrow.left.arrow.right")
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InlineSwitchView: View {
    let s: WidgetSnapshot

    var body: some View {
        Label(s.current?.displayName ?? "Wi-Fi 未接続", systemImage: "wifi")
    }
}

/// まだ Wi-Fi を登録していないとき
struct EmptyWidgetView: View {
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "wifi").font(.title3.weight(.semibold))
            }
        case .accessoryRectangular, .accessoryInline:
            Label("Wi-Fiを登録", systemImage: "wifi")
        default:
            VStack(spacing: 8) {
                IconTile(symbol: "wifi", color: TileColor.blue.color, size: 40)
                Text("アプリでWi-Fiを\n登録してください")
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
