import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: Store
    @State private var editing: WiFiNetwork?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                }

                Section {
                    ForEach(store.data.networks) { n in
                        if n.isConfigured {
                            NetworkRow(network: n,
                                       isCurrent: store.data.currentID == n.id,
                                       isConnecting: store.connectingID == n.id,
                                       onInfo: { editing = n },
                                       onTap: { Task { await store.connect(n.id) } })
                        } else {
                            Button {
                                editing = n
                            } label: {
                                HStack(spacing: 12) {
                                    Color.clear.frame(width: 18)
                                    Text("ネットワーク\(n.slotLabel)を追加…")
                                }
                            }
                        }
                    }
                } header: {
                    Text("ネットワーク")
                } footer: {
                    Text("タップするとそのWi-Fiに接続します。ⓘ で名前やパスワードを変えられます。")
                }

                Section {
                    Button {
                        Task { await store.toggle() }
                    } label: {
                        Label("もう一方に切り替える", systemImage: "arrow.left.arrow.right")
                    }
                    .disabled(store.snapshot.configured.count < 2 || store.connectingID != nil)
                }

                Section {
                    Toggle("切り替え後にホーム画面に戻る", isOn: $store.data.returnHome)
                    if !SharedStore.isShared {
                        if store.calendarAccess {
                            HStack {
                                Text("ウィジェット連携")
                                Spacer()
                                Text("オン").foregroundStyle(.secondary)
                            }
                        } else {
                            Button("カレンダーへのアクセスを許可") {
                                Task { await store.requestCalendar() }
                            }
                        }
                    }
                } header: {
                    Text("ウィジェット")
                } footer: {
                    Text(widgetFooter)
                }
            }
            .navigationTitle("Wi-Fi Changer")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editing) { n in
                NetworkEditView(network: n, password: store.password(for: n.id))
                    .environmentObject(store)
            }
            .alert(store.alert?.title ?? "",
                   isPresented: Binding(get: { store.alert != nil },
                                        set: { if !$0 { store.alert = nil } }),
                   presenting: store.alert) { a in
                if a.offersSettings {
                    Button("設定を開く") { store.openWiFiSettings() }
                }
                Button("OK", role: .cancel) {}
            } message: { a in
                Text(a.message)
            }
            .onChange(of: store.data.returnHome) { _, _ in
                store.persist()
            }
            .onAppear {
                if ProcessInfo.processInfo.arguments.contains("-edit") {
                    editing = store.network("a")
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            IconTile(symbol: "wifi", color: TileColor.blue.color, size: 60)
                .padding(.bottom, 4)
            Text("Wi-Fi Changer")
                .font(.title2.weight(.bold))
            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var statusText: String {
        if let c = store.current {
            return "「\(c.displayName)」に接続中です。"
        }
        if let live = store.liveSSID {
            return "「\(live)」に接続中です（登録していないWi-Fi）。"
        }
        if store.snapshot.configured.isEmpty {
            return "切り替える2つのWi-Fiを登録すると、ウィジェットのタップだけで切り替えられます。"
        }
        return "登録したWi-Fiには接続していません。"
    }

    private var widgetFooter: String {
        var s = "小サイズとロック画面はタップでもう一方へ、中サイズは押したほうへ切り替わります。切り替えるときは一瞬だけアプリが開きます。"
        if !SharedStore.isShared && !store.calendarAccess {
            s += "\nこの署名ではアプリとウィジェットで直接データを共有できないため、カレンダーの2001年1月4日にメモを1件だけ保存してウィジェットに渡します（パスワードは入れません）。"
        }
        return s
    }
}

/// 設定アプリの Wi-Fi の行のような表示
struct NetworkRow: View {
    let network: WiFiNetwork
    let isCurrent: Bool
    let isConnecting: Bool
    let onInfo: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if isConnecting {
                    ProgressView().controlSize(.small)
                } else if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
            .frame(width: 18)

            IconTile(symbol: network.symbol, color: network.tint.color)

            VStack(alignment: .leading, spacing: 1) {
                Text(network.displayName)
                    .foregroundStyle(.primary)
                if network.displayName != network.ssid {
                    Text(network.ssid)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                if network.security == .wpa {
                    Image(systemName: "lock.fill")
                        .font(.footnote)
                }
                Image(systemName: "wifi")
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)

            Button(action: onInfo) {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
