import SwiftUI

struct AttributionsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        ScrollView(.vertical) {
            HStack {
                VStack(alignment: .leading, spacing: 20) {
                    Text(NSLocalizedString("Attributions", comment: ""))
                        .font(.title)
                        .bold()
                    Text(NSLocalizedString("FloatMarket is built with SwiftUI, AppKit, URLSession, and official market data interfaces.", comment: ""))
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(settingsStore.settings.floatingThemeMode.preferredColorScheme)
    }
}