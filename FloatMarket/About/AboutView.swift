import SwiftUI

struct AboutView: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    let icon: NSImage
    let name: String
    let version: String
    let build: String
    let copyright: String
    let developerName: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 18) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(radius: 6, y: 4)
                VStack(alignment: .leading) {
                    HStack(alignment: .top) {
                        Text(name)
                            .font(.title)
                            .bold()
                        Spacer()
                        Text(String(format: NSLocalizedString("Version %@ (%@)", comment: ""), version, build))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Text(NSLocalizedString("A floating macOS market board for global indices and perpetual contracts, with proxy support, bilingual UI, and switchable appearance.", comment: ""))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 10) {
                        infoRow(NSLocalizedString("Product", comment: ""), value: NSLocalizedString("FloatMarket", comment: ""))
                        infoRow(NSLocalizedString("Developer", comment: ""), value: developerName)
                        infoRow(NSLocalizedString("Repository", comment: ""), value: "https://github.com/XRSec/FloatMarket")
                        infoRow(NSLocalizedString("Platform", comment: ""), value: "macOS 13 Ventura+")
                    }
                    .padding(.top, 16)

                    Spacer(minLength: 0)
                    Text(copyright)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(24)

            HStack {
                Spacer()
                Button {
                    AttributionsWindow.show(settingsStore: settingsStore)
                } label: {
                    Text(NSLocalizedString("Attributions", comment: ""))
                }
            }
            .padding()
            .background(.bar)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(settingsStore.settings.floatingThemeMode.preferredColorScheme)
    }

    private func infoRow(_ title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}
