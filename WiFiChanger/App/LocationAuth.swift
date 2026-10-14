import CoreLocation
import UIKit

/// Wi-Fi の名前を読むための位置情報の許可（位置そのものは使わない）
@MainActor
final class LocationAuth: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published private(set) var status: CLAuthorizationStatus
    @Published private(set) var precise: Bool

    /// 許可が変わったとき
    var onChange: (() -> Void)?

    override init() {
        status = manager.authorizationStatus
        precise = manager.accuracyAuthorization == .fullAccuracy
        super.init()
        manager.delegate = self
    }

    var authorized: Bool { status == .authorizedWhenInUse || status == .authorizedAlways }

    func request() {
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let s = manager.authorizationStatus
        let p = manager.accuracyAuthorization == .fullAccuracy
        Task { @MainActor in
            self.status = s
            self.precise = p
            self.onChange?()
        }
    }
}
