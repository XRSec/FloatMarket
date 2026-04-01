import SwiftUI

struct Sidebar: View {
    @EnvironmentObject private var store: MarketStore
    @Binding var selection: SettingsSection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerTitle

                group(
                    title: NSLocalizedString("Workspace", comment: ""),
                    items: [.general, .dataSources, .watchlist, .appearance]
                )
                group(
                    title: NSLocalizedString("Operations", comment: ""),
                    items: [.logs]
                )
            }
            .padding(.top, 18)
            .padding(.horizontal, 10)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.bar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                footer
            }
        }
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Bundle.main.name)
                .font(.system(size: 15, weight: .semibold))
        }
        .padding(.top, 24)
        .padding(.leading, 24)
    }

    private func group(title: String, items: [SettingsSection]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(items, id: \.self) { item in
                row(item)
            }
        }
    }

    private func row(_ item: SettingsSection) -> some View {
        Button {
            selection = item
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.systemImage)
                    .frame(width: 18)
                    .foregroundStyle(selection == item ? Color.accentColor : .secondary)

                Text(localizedTitle(for: item))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                if selection == item {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selection == item ? Color.accentColor.opacity(0.14) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selection == item ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.04), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: store.statusSymbolName)
                    .foregroundStyle(store.statusSymbolColor)
                Text(store.popupStatusText)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }

            Text(store.menuBarStatusDetail)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(store.headerStatusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }

    private func localizedTitle(for item: SettingsSection) -> String {
        switch item {
        case .general:
            return NSLocalizedString("General", comment: "")
        case .dataSources:
            return NSLocalizedString("Data Sources", comment: "")
        case .watchlist:
            return NSLocalizedString("Watchlist", comment: "")
        case .appearance:
            return NSLocalizedString("Appearance", comment: "")
        case .logs:
            return NSLocalizedString("Logs", comment: "")
        }
    }
}
