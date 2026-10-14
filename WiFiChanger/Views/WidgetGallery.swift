import SwiftUI

/// ウィジェットの見た目を確かめる画面（起動引数 -gallery のときだけ）
struct WidgetGallery: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        let s = store.snapshot
        ScrollView {
            VStack(spacing: 24) {
                HStack(spacing: 20) {
                    frame(170, 170) { SmallSwitchView(s: s) }
                    frame(170, 170) { SmallSwitchView(s: WidgetSnapshot(networks: s.networks, currentID: nil, updated: Date())) }
                }
                frame(364, 170) { MediumSwitchView(s: s) }
                HStack(spacing: 20) {
                    accessory(76, 76) { CircularSwitchView(s: s) }
                    accessory(172, 76) { RectangularSwitchView(s: s) }
                }
                frame(170, 170) { EmptyWidgetView(family: .systemSmall) }
            }
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func frame<V: View>(_ w: CGFloat, _ h: CGFloat, @ViewBuilder _ content: () -> V) -> some View {
        content()
            .padding(16)
            .frame(width: w, height: h)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }

    private func accessory<V: View>(_ w: CGFloat, _ h: CGFloat, @ViewBuilder _ content: () -> V) -> some View {
        content()
            .frame(width: w, height: h)
            .foregroundStyle(.white)
            .environment(\.colorScheme, .dark)
            .padding(8)
            .background(Color.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
