import Foundation
import EventKit

/// アプリの設定（パスワード以外）
struct AppData: Codable, Equatable {
    var networks: [WiFiNetwork] = [.empty("a"), .empty("b")]
    var currentID: String?
    /// ウィジェットから切り替えたあと、ホーム画面に戻る
    var returnHome: Bool = true

    var snapshot: WidgetSnapshot {
        WidgetSnapshot(networks: networks, currentID: currentID, updated: Date())
    }
}

/// 保存場所。App Group が使える署名なら、アプリとウィジェットで同じ場所を使う
enum SharedStore {
    static let appGroupID: String? = {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String,
              !id.isEmpty, !id.contains("$(") else { return nil }
        return id
    }()

    /// App Group が実際に使えるか（署名に App Group が入っているか）
    static var isShared: Bool {
        guard let id = appGroupID else { return false }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) != nil
    }

    static var groupDefaults: UserDefaults? {
        guard isShared, let id = appGroupID else { return nil }
        return UserDefaults(suiteName: id)
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: アプリの設定

    private static let dataKey = "data.v1"

    static func loadData() -> AppData {
        guard let data = UserDefaults.standard.data(forKey: dataKey),
              var file = try? decoder.decode(AppData.self, from: data) else { return AppData() }
        for id in ["a", "b"] where !file.networks.contains(where: { $0.id == id }) {
            file.networks.append(.empty(id))
        }
        file.networks.sort { $0.id < $1.id }
        return file
    }

    static func saveData(_ file: AppData) {
        guard let data = try? encoder.encode(file) else { return }
        UserDefaults.standard.set(data, forKey: dataKey)
    }

    // MARK: ウィジェット用

    private static let snapshotKey = "snapshot.v1"

    static func saveSnapshot(_ snapshot: WidgetSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        groupDefaults?.set(data, forKey: snapshotKey)
        CalendarBridge.write(data)
    }

    /// ウィジェットが読む：App Group → カレンダーのメモ の順
    static func loadSnapshot() -> WidgetSnapshot? {
        if let data = groupDefaults?.data(forKey: snapshotKey),
           let s = try? decoder.decode(WidgetSnapshot.self, from: data) {
            return s
        }
        if let data = CalendarBridge.read(),
           let s = try? decoder.decode(WidgetSnapshot.self, from: data) {
            return s
        }
        return nil
    }
}

/// App Group が使えない署名でも、ウィジェットに設定を渡すための仕組み（StudyPlan・MoneyPlan と同じ方法）。
/// 2001年1月4日に終日の予定を1件だけ作り、メモ欄に保存する（ふだんのカレンダー表示には出てこない日付）。
/// パスワードは入れない。
enum CalendarBridge {
    static let title = "Wi-Fi Changer の設定"
    static let marker = "[wifichanger-v1]"

    private static var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return c
    }()

    static var day: Date {
        var c = DateComponents()
        c.year = 2001; c.month = 1; c.day = 4
        return calendar.date(from: c) ?? Date(timeIntervalSinceReferenceDate: 3 * 86_400)
    }

    static var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    static var denied: Bool {
        let s = EKEventStore.authorizationStatus(for: .event)
        return s == .denied || s == .restricted || s == .writeOnly
    }

    private static func events(in store: EKEventStore) -> [EKEvent] {
        let end = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        let predicate = store.predicateForEvents(withStart: day, end: end, calendars: nil)
        return store.events(matching: predicate).filter { ($0.notes ?? "").contains(marker) }
    }

    static func read(store: EKEventStore = EKEventStore()) -> Data? {
        guard hasAccess else { return nil }
        for event in events(in: store) {
            guard let notes = event.notes, let range = notes.range(of: marker) else { continue }
            let json = notes[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if let data = json.data(using: .utf8) { return data }
        }
        return nil
    }

    @discardableResult
    static func write(_ data: Data, store: EKEventStore = EKEventStore()) -> Bool {
        guard hasAccess else { return false }
        let existing = events(in: store)
        guard !SharedStore.isShared else {
            // App Group が使えるならカレンダーには書かない（前に書いた分は消す）
            for e in existing { try? store.remove(e, span: .thisEvent, commit: false) }
            try? store.commit()
            return true
        }
        guard let json = String(data: data, encoding: .utf8) else { return false }
        let notes = "Wi-Fi Changer のウィジェット用の設定です（パスワードは入っていません）。消してもアプリの設定は消えません。\n\(marker)\n\(json)"
        let event = existing.first ?? EKEvent(eventStore: store)
        if existing.first == nil {
            guard let cal = store.defaultCalendarForNewEvents
                    ?? store.calendars(for: .event).first(where: { $0.allowsContentModifications }) else { return false }
            event.calendar = cal
            event.title = title
            event.isAllDay = true
            event.startDate = day
            event.endDate = day
        }
        guard event.notes != notes else { return true }
        event.notes = notes
        do {
            try store.save(event, span: .thisEvent, commit: true)
            for e in existing.dropFirst() { try? store.remove(e, span: .thisEvent, commit: false) }
            try? store.commit()
            return true
        } catch {
            return false
        }
    }
}
