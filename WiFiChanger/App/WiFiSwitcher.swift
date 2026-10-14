import Foundation
import NetworkExtension
import Security

/// Wi-Fi の切り替え（NEHotspotConfiguration）
enum WiFiSwitcher {
    enum Failure: LocalizedError {
        case notConfigured
        case missingPassword
        case denied
        case notAllowed
        case systemNetwork(String)
        case badPassword
        case badSSID
        case notForeground
        case pending
        case notJoined(String)
        case other(String)

        var title: String {
            switch self {
            case .notConfigured: return "Wi-Fiが登録されていません"
            case .missingPassword, .badPassword: return "パスワードを確認してください"
            case .denied: return "接続がキャンセルされました"
            case .notAllowed: return "Wi-Fiを切り替えられません"
            case .systemNetwork: return "設定アプリで保存したWi-Fiです"
            case .badSSID: return "SSIDを確認してください"
            case .notForeground, .pending: return "もう一度お試しください"
            case .notJoined: return "接続できませんでした"
            case .other: return "接続できませんでした"
            }
        }

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "アプリを開いて、切り替える2つのWi-Fiを登録してください。"
            case .missingPassword:
                return "このネットワークのパスワードが保存されていません。ⓘ からパスワードを入力してください。"
            case .badPassword:
                return "パスワードは8〜63文字で入力してください。"
            case .denied:
                return "「接続」を選ぶと切り替わります。"
            case .notAllowed:
                return "この署名ではWi-Fiの切り替え（Hotspot Configuration）が許可されていない可能性があります。署名ツールでこの機能を含めて署名し直してください。"
            case .systemNetwork(let ssid):
                return "「\(ssid)」は設定アプリで保存されているため、アプリから切り替えられません。設定 › Wi-Fi で「\(ssid)」の ⓘ →「このネットワーク設定を削除」をしてから、もう一度アプリで接続してください。"
            case .badSSID:
                return "SSIDは1〜32バイトで入力してください。"
            case .notForeground:
                return "アプリが前面にあるときだけ切り替えられます。"
            case .pending:
                return "前の切り替えが終わるのを待ってから、もう一度タップしてください。"
            case .notJoined(let ssid):
                return "「\(ssid)」に接続できたか確認できませんでした。電波が届く場所か、パスワードが正しいかを確認してください。"
            case .other(let message):
                return message
            }
        }

        /// 設定アプリへのボタンを出すか
        var offersSettings: Bool {
            switch self {
            case .systemNetwork, .notJoined: return true
            default: return false
            }
        }
    }

    /// いま接続している SSID。このアプリで登録したネットワークなら位置情報なしで分かる
    static func currentSSID() async -> String? {
        #if targetEnvironment(simulator)
        return nil
        #else
        return await withCheckedContinuation { c in
            NEHotspotNetwork.fetchCurrent { network in
                c.resume(returning: network?.ssid)
            }
        }
        #endif
    }

    static func join(_ network: WiFiNetwork, password: String?) async throws {
        let ssid = network.ssid
        guard network.isConfigured else { throw Failure.notConfigured }
        guard ssid.utf8.count <= 32 else { throw Failure.badSSID }

        let config: NEHotspotConfiguration
        switch network.security {
        case .open:
            config = NEHotspotConfiguration(ssid: ssid)
        case .wpa:
            guard let pw = password, !pw.isEmpty else { throw Failure.missingPassword }
            guard (8...63).contains(pw.count) else { throw Failure.badPassword }
            config = NEHotspotConfiguration(ssid: ssid, passphrase: pw, isWEP: false)
        }
        config.joinOnce = false

        let error: Error? = await withCheckedContinuation { c in
            NEHotspotConfigurationManager.shared.apply(config) { err in
                c.resume(returning: err)
            }
        }
        guard let error else { return }
        let ns = error as NSError
        guard ns.domain == NEHotspotConfigurationErrorDomain else {
            throw Failure.other(ns.localizedDescription)
        }
        switch ns.code {
        case NEHotspotConfigurationError.alreadyAssociated.rawValue:
            return
        case NEHotspotConfigurationError.userDenied.rawValue:
            throw Failure.denied
        case NEHotspotConfigurationError.systemConfiguration.rawValue:
            throw Failure.systemNetwork(ssid)
        case NEHotspotConfigurationError.invalidWPAPassphrase.rawValue:
            throw Failure.badPassword
        case NEHotspotConfigurationError.invalidSSID.rawValue:
            throw Failure.badSSID
        case NEHotspotConfigurationError.applicationIsNotInForeground.rawValue:
            throw Failure.notForeground
        case NEHotspotConfigurationError.pending.rawValue:
            throw Failure.pending
        case NEHotspotConfigurationError.userUnauthorized.rawValue,
             NEHotspotConfigurationError.systemDenied.rawValue,
             NEHotspotConfigurationError.unknown.rawValue,
             NEHotspotConfigurationError.invalid.rawValue:
            throw Failure.notAllowed
        default:
            // 署名に Hotspot Configuration が入っていないときは「内部エラー」になる
            throw Failure.notAllowed
        }
    }

    /// アプリで登録した設定を消す（iPhone に保存された Wi-Fi から外れる）
    static func remove(ssid: String) {
        #if !targetEnvironment(simulator)
        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
        #endif
    }
}

/// パスワードはキーチェーンに保存（使えない署名のときはアプリ内に保存）
enum PasswordStore {
    private static let service = "app.wifichanger.password"

    private static func query(_ id: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: id]
    }

    static func get(_ id: String) -> String? {
        var q = query(id)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        if SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
           let data = out as? Data, let s = String(data: data, encoding: .utf8) {
            return s
        }
        return UserDefaults.standard.string(forKey: "pw.\(id)")
    }

    static func set(_ value: String?, for id: String) {
        SecItemDelete(query(id) as CFDictionary)
        UserDefaults.standard.removeObject(forKey: "pw.\(id)")
        guard let value, !value.isEmpty else { return }
        var add = query(id)
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        if SecItemAdd(add as CFDictionary, nil) != errSecSuccess {
            UserDefaults.standard.set(value, forKey: "pw.\(id)")
        }
    }
}
