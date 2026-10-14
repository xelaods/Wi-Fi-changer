import SwiftUI

struct NetworkEditView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var network: WiFiNetwork
    @State private var password: String
    @State private var showPassword = false
    @State private var confirmDelete = false
    private let isNew: Bool

    init(network: WiFiNetwork, password: String) {
        _network = State(initialValue: network)
        _password = State(initialValue: password)
        isNew = !network.isConfigured
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        IconTile(symbol: network.symbol, color: network.tint.color, size: 60)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .padding(.vertical, -4)
                }

                Section {
                    field("名前", prompt: "例：家（5GHz）", text: $network.name)
                    field("SSID", prompt: "必須", text: $network.ssid)
                    Picker("セキュリティ", selection: $network.security) {
                        ForEach(WiFiSecurity.allCases) { s in
                            Text(s.label).tag(s)
                        }
                    }
                    if network.security == .wpa {
                        HStack {
                            Text("パスワード")
                            Group {
                                if showPassword {
                                    TextField("", text: $password, prompt: Text("必須"))
                                } else {
                                    SecureField("", text: $password, prompt: Text("必須"))
                                }
                            }
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } footer: {
                    Text("SSIDは大文字・小文字も含めて、設定 › Wi-Fi に出ている名前のとおりに入力してください。パスワードはこのiPhoneの中だけに保存します。")
                }

                Section("アイコン") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 12) {
                        ForEach(WiFiNetwork.symbols, id: \.self) { symbol in
                            Button {
                                network.symbol = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.system(size: 17, weight: .semibold))
                                    .frame(width: 40, height: 40)
                                    .foregroundStyle(network.symbol == symbol ? .white : .secondary)
                                    .background(Circle().fill(network.symbol == symbol ? AnyShapeStyle(network.tint.color) : AnyShapeStyle(Color(.tertiarySystemFill))))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)

                    HStack(spacing: 0) {
                        ForEach(TileColor.allCases) { c in
                            Button {
                                network.tint = c
                            } label: {
                                Circle()
                                    .fill(c.color)
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        if network.tint == c {
                                            Circle().strokeBorder(Color(.systemBackground), lineWidth: 3)
                                            Circle().strokeBorder(c.color, lineWidth: 2).padding(-4)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                if !isNew {
                    Section {
                        Button("このネットワークを削除", role: .destructive) {
                            confirmDelete = true
                        }
                    } footer: {
                        Text("アプリで登録したWi-Fiの設定もiPhoneから削除されます。")
                    }
                }
            }
            .navigationTitle(isNew ? "ネットワーク\(network.slotLabel)を追加" : network.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.save(network, password: password)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .confirmationDialog("「\(network.displayName)」を削除しますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    store.clear(network.id)
                    dismiss()
                }
            }
        }
    }

    private func field(_ label: String, prompt: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            TextField("", text: text, prompt: Text(prompt))
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    private var isValid: Bool {
        let ssid = network.ssid.trimmingCharacters(in: .whitespaces)
        guard !ssid.isEmpty, ssid.utf8.count <= 32 else { return false }
        if network.security == .wpa {
            return (8...63).contains(password.count)
        }
        return true
    }
}
