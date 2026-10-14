import SwiftUI
import UIKit
import EventKit
import WidgetKit

struct AppAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    var offersSettings = false
}

@MainActor
final class Store: ObservableObject {
    @Published var data: AppData
    /// いま切り替え中のネットワーク
    @Published var connectingID: String?
    /// 実際に接続している SSID（分かるときだけ）
    @Published var liveSSID: String?
    @Published var alert: AppAlert?
    @Published var calendarAccess = CalendarBridge.hasAccess

    let demo: Bool

    init() {
        let args = ProcessInfo.processInfo.arguments
        demo = args.contains("-demo")
        if demo {
            var d = AppData()
            d.networks = WidgetSnapshot.placeholder.networks
            d.currentID = "a"
            data = d
        } else {
            data = SharedStore.loadData()
        }
    }

    var snapshot: WidgetSnapshot { data.snapshot }

    func network(_ id: String) -> WiFiNetwork {
        data.networks.first { $0.id == id } ?? .empty(id)
    }

    var current: WiFiNetwork? { snapshot.current }

    func password(for id: String) -> String {
        demo ? "" : (PasswordStore.get(id) ?? "")
    }

    // MARK: 保存

    func persist() {
        guard !demo else { return }
        SharedStore.saveData(data)
        SharedStore.saveSnapshot(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func save(_ network: WiFiNetwork, password: String) {
        guard let i = data.networks.firstIndex(where: { $0.id == network.id }) else { return }
        let old = data.networks[i]
        var n = network
        n.name = n.name.trimmingCharacters(in: .whitespaces)
        if old.isConfigured, old.ssid != n.ssid {
            WiFiSwitcher.remove(ssid: old.ssid)
            if data.currentID == n.id { data.currentID = nil }
        }
        data.networks[i] = n
        if !demo {
            PasswordStore.set(n.security == .open ? nil : password, for: n.id)
        }
        persist()
    }

    func clear(_ id: String) {
        guard let i = data.networks.firstIndex(where: { $0.id == id }) else { return }
        let old = data.networks[i]
        if old.isConfigured { WiFiSwitcher.remove(ssid: old.ssid) }
        data.networks[i] = .empty(id)
        if !demo { PasswordStore.set(nil, for: id) }
        if data.currentID == id { data.currentID = nil }
        persist()
    }

    // MARK: 状態

    /// 実際の接続先を読み直す（読めないときは前回の切り替え結果を使う）
    func refresh() async {
        calendarAccess = CalendarBridge.hasAccess
        guard !demo else { return }
        if let ssid = await WiFiSwitcher.currentSSID() {
            liveSSID = ssid
            data.currentID = data.networks.first { $0.isConfigured && $0.ssid == ssid }?.id
        }
        persist()
    }

    // MARK: 切り替え

    func connect(_ id: String, fromWidget: Bool = false) async {
        guard connectingID == nil else { return }
        let n = network(id)
        guard n.isConfigured else {
            show(WiFiSwitcher.Failure.notConfigured)
            return
        }
        connectingID = id
        defer { connectingID = nil }

        if demo {
            try? await Task.sleep(for: .seconds(1))
            data.currentID = id
            return
        }

        do {
            try await WiFiSwitcher.join(n, password: password(for: id))
        } catch let f as WiFiSwitcher.Failure {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            show(f)
            return
        } catch {
            show(.other(error.localizedDescription))
            return
        }

        data.currentID = id
        persist()

        // 実際につながるまで少し待って確かめる
        var joined: String?
        for _ in 0..<10 {
            joined = await WiFiSwitcher.currentSSID()
            if joined == n.ssid { break }
            try? await Task.sleep(for: .milliseconds(500))
        }
        if let joined { liveSSID = joined }

        if let joined, joined != n.ssid {
            data.currentID = data.networks.first { $0.isConfigured && $0.ssid == joined }?.id
            persist()
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            show(.notJoined(n.ssid))
            return
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if fromWidget && data.returnHome {
            try? await Task.sleep(for: .milliseconds(400))
            goHome()
        }
    }

    /// もう一方に切り替える
    func toggle(fromWidget: Bool = false) async {
        await refresh()
        guard let next = snapshot.next else {
            show(.notConfigured)
            return
        }
        await connect(next.id, fromWidget: fromWidget)
    }

    /// ウィジェットから開かれたとき
    func handle(_ url: URL) async {
        guard url.scheme == Links.scheme else { return }
        // アプリが前面に来るのを少し待つ（前面でないと切り替えられない）
        try? await Task.sleep(for: .milliseconds(350))
        switch url.host {
        case "connect":
            let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "to" }?.value ?? ""
            if ["a", "b"].contains(id) { await connect(id, fromWidget: true) }
        case "toggle":
            await toggle(fromWidget: true)
        default:
            break
        }
    }

    private func show(_ f: WiFiSwitcher.Failure) {
        alert = AppAlert(title: f.title, message: f.errorDescription ?? "", offersSettings: f.offersSettings)
    }

    /// ホーム画面に戻る
    private func goHome() {
        UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
    }

    func openWiFiSettings() {
        let wifi = URL(string: "App-prefs:WIFI")!
        UIApplication.shared.open(wifi, options: [:]) { ok in
            if !ok, let s = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(s)
            }
        }
    }

    // MARK: ウィジェット連携（App Group が使えない署名のとき）

    func requestCalendar() async {
        let store = EKEventStore()
        let ok = (try? await store.requestFullAccessToEvents()) ?? false
        calendarAccess = ok
        if ok {
            persist()
        } else if CalendarBridge.denied, let s = URL(string: UIApplication.openSettingsURLString) {
            await UIApplication.shared.open(s)
        }
    }
}
