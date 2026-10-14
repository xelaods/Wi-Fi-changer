import Foundation
import NetworkExtension
import CoreLocation

/// いま接続しているWi-FiのSSIDを読む。
/// iOS では位置情報（正確な位置情報）の許可と wifi-info の権限があるときだけ、どのWi-Fiでも名前が分かる。
enum LiveWiFi {
    /// 読み取りに一度でも成功したか（失敗＝未接続なのか、権限がなくて読めないのかを見分けるため）
    private static let worksKey = "liveWiFi.works"

    static var hasWorked: Bool {
        get { UserDefaults.standard.bool(forKey: worksKey) }
        set { UserDefaults.standard.set(newValue, forKey: worksKey) }
    }

    /// アプリ本体で位置情報が許可されているか
    static var appAuthorized: Bool {
        let s = CLLocationManager().authorizationStatus
        return s == .authorizedWhenInUse || s == .authorizedAlways
    }

    static func fetch(_ completion: @escaping (String?) -> Void) {
        #if targetEnvironment(simulator)
        completion(nil)
        #else
        NEHotspotNetwork.fetchCurrent { network in
            completion(network?.ssid)
        }
        #endif
    }

    /// 読み取った結果。読めたかどうか分からないときは nil（前回の記録を使う）
    enum Result: Equatable {
        case connected(String)
        case notConnected
        case unknown
    }

    /// authorized: 位置情報が許可されているか
    static func read(authorized: Bool, _ completion: @escaping (Result) -> Void) {
        fetch { ssid in
            if let ssid, !ssid.isEmpty {
                hasWorked = true
                completion(.connected(ssid))
            } else if authorized && hasWorked {
                completion(.notConnected)
            } else {
                completion(.unknown)
            }
        }
    }

    static func read(authorized: Bool) async -> Result {
        await withCheckedContinuation { c in
            read(authorized: authorized) { c.resume(returning: $0) }
        }
    }
}
