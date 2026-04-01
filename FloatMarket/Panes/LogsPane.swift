import SwiftUI

struct LogsPane: View {
    @EnvironmentObject private var store: MarketStore
    @State private var selectedLevel: LogLevel?
    @State private var selectedLogIDs = Set<LogEntry.ID>()

    private var infoCount: Int {
        store.logEntries.filter { $0.level == .info }.count
    }

    private var warningCount: Int {
        store.logEntries.filter { $0.level == .warning }.count
    }

    private var errorCount: Int {
        store.logEntries.filter { $0.level == .error }.count
    }

    private var filteredEntries: [LogEntry] {
        guard let selectedLevel else { return store.logEntries }
        return store.logEntries.filter { $0.level == selectedLevel }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox {
                HStack(spacing: 12) {
                    logMetricButton(
                        title: NSLocalizedString("Total", comment: ""),
                        value: "\(store.logEntries.count)",
                        tint: .accentColor,
                        isSelected: selectedLevel == nil
                    ) {
                        selectedLevel = nil
                    }
                    logMetricButton(
                        title: NSLocalizedString("Info", comment: ""),
                        value: "\(infoCount)",
                        tint: Color(red: 0.34, green: 0.73, blue: 0.98),
                        isSelected: selectedLevel == .info
                    ) {
                        toggleFilter(.info)
                    }
                    logMetricButton(
                        title: NSLocalizedString("Warnings", comment: ""),
                        value: "\(warningCount)",
                        tint: Color(red: 0.98, green: 0.72, blue: 0.25),
                        isSelected: selectedLevel == .warning
                    ) {
                        toggleFilter(.warning)
                    }
                    logMetricButton(
                        title: NSLocalizedString("Errors", comment: ""),
                        value: "\(errorCount)",
                        tint: Color(red: 0.96, green: 0.37, blue: 0.35),
                        isSelected: selectedLevel == .error
                    ) {
                        toggleFilter(.error)
                    }
                    Spacer()
                    Button(NSLocalizedString("Clear Logs", comment: "")) {
                        store.clearLogs()
                        selectedLevel = nil
                        selectedLogIDs.removeAll()
                    }
                    .buttonStyle(.bordered)
                }
            } label: {
                ControlCenterSectionLabel(
                    title: NSLocalizedString("Overview", comment: ""),
                    subtitle: NSLocalizedString("Check counts first, then click a metric to filter the event list.", comment: "")
                )
            }

            GroupBox {
                if store.logEntries.isEmpty {
                    ControlCenterEmptyState(
                        systemImage: "doc.text.magnifyingglass",
                        title: NSLocalizedString("No Logs Yet", comment: ""),
                        message: NSLocalizedString("Request failures, fallbacks, proxy test results, and decoding issues will appear here.", comment: "")
                    )
                } else if filteredEntries.isEmpty {
                    ControlCenterEmptyState(
                        systemImage: "line.3.horizontal.decrease.circle",
                        title: NSLocalizedString("No Matching Logs", comment: ""),
                        message: NSLocalizedString("The current filter has no matching log entries. Switch back to Total or pick another level.", comment: "")
                    )
                } else {
                    Table(filteredEntries, selection: $selectedLogIDs) {
                        TableColumn(NSLocalizedString("Time", comment: "")) { entry in
                            Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                        }

                        TableColumn(NSLocalizedString("Level", comment: "")) { entry in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(entry.level.color)
                                    .frame(width: 8, height: 8)
                                Text(localizedLevel(entry.level))
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        }

                        TableColumn(NSLocalizedString("Message", comment: "")) { entry in
                            Text(entry.message)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 420)
                    .background(
                        LogsCopyShortcutBridge(copyAction: copySelectedLogs)
                    )
                    .contextMenu {
                        Button(NSLocalizedString("Copy Selected", comment: "")) {
                            copySelectedLogs()
                        }
                        .disabled(selectedLogIDs.isEmpty)
                    }
                }
            } label: {
                ControlCenterSectionLabel(
                    title: NSLocalizedString("Events", comment: ""),
                    subtitle: NSLocalizedString("Events are shown newest first so current issues stay on top.", comment: "")
                )
            }
        }
        .padding(.top, 26)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.clear)
        .groupBoxStyle(ControlCenterGroupBoxStyle())
    }

    private func logMetricButton(
        title: String,
        value: String,
        tint: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(tint)
                        .frame(width: 8, height: 8)
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .monospacedDigit()
            }
            .padding(12)
            .frame(minWidth: 92, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? tint.opacity(0.16) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.45) : Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func toggleFilter(_ level: LogLevel) {
        selectedLevel = selectedLevel == level ? nil : level
        selectedLogIDs.removeAll()
    }

    private func copySelectedLogs() {
        let selectedEntries = filteredEntries.filter { selectedLogIDs.contains($0.id) }
        guard !selectedEntries.isEmpty else { return }

        let content = selectedEntries.map { entry in
            let time = entry.timestamp.formatted(date: .omitted, time: .standard)
            let level = localizedLevel(entry.level)
            return "[\(time)] [\(level)] \(entry.message)"
        }.joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }

    private func localizedLevel(_ level: LogLevel) -> String {
        switch level {
        case .info:
            return NSLocalizedString("Info", comment: "")
        case .warning:
            return NSLocalizedString("Warning", comment: "")
        case .error:
            return NSLocalizedString("Error", comment: "")
        }
    }
}

private struct LogsCopyShortcutBridge: NSViewRepresentable {
    let copyAction: () -> Void

    func makeNSView(context: Context) -> LogsCopyShortcutView {
        let view = LogsCopyShortcutView()
        view.copyAction = copyAction
        return view
    }

    func updateNSView(_ nsView: LogsCopyShortcutView, context: Context) {
        nsView.copyAction = copyAction
    }
}

final class LogsCopyShortcutView: NSView {
    var copyAction: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command],
              event.charactersIgnoringModifiers?.lowercased() == "c"
        else {
            return super.performKeyEquivalent(with: event)
        }

        copyAction?()
        return true
    }
}
