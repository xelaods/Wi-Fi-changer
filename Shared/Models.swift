import Foundation
import SwiftUI

/// Wi-Fi のセキュリティ（パーソナルのみ）
enum WiFiSecurity: String, Codable, CaseIterable, Identifiable {
    case wpa
    case open

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wpa: return "WPA/WPA2/WPA3"
        case .open: return "なし"
        }
    }
}

/// アイコンの色（設定アプリのアイコンのような色）
enum TileColor: String, Codable, CaseIterable, Identifiable {
    case blue, green, orange, red, purple, teal, pink, gray

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: return Color(red: 0.0, green: 0.48, blue: 1.0)
        case .green: return Color(red: 0.20, green: 0.78, blue: 0.35)
        case .orange: return Color(red: 1.0, green: 0.58, blue: 0.0)
        case .red: return Color(red: 1.0, green: 0.23, blue: 0.19)
        case .purple: return Color(red: 0.69, green: 0.32, blue: 0.87)
        case .teal: return Color(red: 0.19, green: 0.69, blue: 0.78)
        case .pink: return Color(red: 1.0, green: 0.18, blue: 0.33)
        case .gray: return Color(red: 0.56, green: 0.56, blue: 0.58)
        }
    }
}

/// 切り替える Wi-Fi（A と B の2つ）。パスワードはここには入れない（キーチェーンに保存）
struct WiFiNetwork: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var name: String = ""
    var ssid: String = ""
    var security: WiFiSecurity = .wpa
    var symbol: String = "wifi"
    var tint: TileColor = .blue

    var isConfigured: Bool { !ssid.trimmingCharacters(in: .whitespaces).isEmpty }

    var displayName: String {
        let n = name.trimmingCharacters(in: .whitespaces)
        if !n.isEmpty { return n }
        return isConfigured ? ssid : "ネットワーク\(slotLabel)"
    }

    var slotLabel: String { id == "a" ? "A" : "B" }

    static func empty(_ id: String) -> WiFiNetwork {
        WiFiNetwork(id: id,
                    symbol: id == "a" ? "house.fill" : "wifi",
                    tint: id == "a" ? .blue : .orange)
    }

    static let symbols = [
        "wifi", "house.fill", "building.2.fill", "graduationcap.fill",
        "briefcase.fill", "cup.and.saucer.fill", "tram.fill", "gamecontroller.fill",
        "bolt.fill", "moon.fill", "hare.fill", "tortoise.fill",
    ]
}

/// ウィジェットに渡す情報
struct WidgetSnapshot: Codable, Equatable {
    var networks: [WiFiNetwork]
    var currentID: String?
    var updated: Date

    func network(_ id: String) -> WiFiNetwork? { networks.first { $0.id == id } }

    var current: WiFiNetwork? {
        guard let id = currentID else { return nil }
        return network(id)
    }

    var configured: [WiFiNetwork] { networks.filter(\.isConfigured) }

    /// 登録していないWi-Fiに接続しているときのSSID
    var otherSSID: String? = nil

    /// いま接続しているWi-Fiの表示名（登録したものなら付けた名前、それ以外はSSID）
    var connectedName: String? { current?.displayName ?? otherSSID }

    /// 実際の接続先（SSID）を当てはめる。nil はWi-Fiにつながっていない
    mutating func apply(liveSSID ssid: String?) {
        if let ssid, let n = configured.first(where: { $0.ssid == ssid }) {
            currentID = n.id
            otherSSID = nil
        } else {
            currentID = nil
            otherSSID = ssid
        }
    }

    /// タップしたときに切り替わる先
    var next: WiFiNetwork? {
        let list = configured
        if let cur = currentID, let other = list.first(where: { $0.id != cur }) { return other }
        return list.first
    }

    static let placeholder = WidgetSnapshot(networks: [
        WiFiNetwork(id: "a", name: "5GHz", ssid: "Home-5G", symbol: "hare.fill", tint: .blue),
        WiFiNetwork(id: "b", name: "2.4GHz", ssid: "Home-2G", symbol: "tortoise.fill", tint: .orange),
    ], currentID: "a", updated: Date())
}

/// ウィジェットからアプリを開くときのリンク
enum Links {
    static let scheme = "wifichanger"
    static func connect(_ id: String) -> URL { URL(string: "\(scheme)://connect?to=\(id)")! }
    static let toggle = URL(string: "\(scheme)://toggle")!
    static let open = URL(string: "\(scheme)://open")!
}
