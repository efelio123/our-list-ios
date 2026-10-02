import SwiftUI
import WidgetKit
import AppIntents

struct WidgetSetupIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Our List"
    static var description = IntentDescription("Show your shared list.")

    @Parameter(title: "List code", description: "Copy the code from the Our List app")
    var listCode: String

    init() { listCode = "" }
}

struct ListEntry: TimelineEntry {
    let date: Date
    let code: String
    let items: [TodoItem]
    let message: String?
}

struct ListProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ListEntry {
        ListEntry(date: .now, code: "", items: [], message: nil)
    }

    func snapshot(for configuration: WidgetSetupIntent, in context: Context) async -> ListEntry {
        await load(configuration.listCode)
    }

    func timeline(for configuration: WidgetSetupIntent, in context: Context) async -> Timeline<ListEntry> {
        let entry = await load(configuration.listCode)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60)))
    }

    private func load(_ value: String) async -> ListEntry {
        guard !value.isEmpty else {
            return ListEntry(date: .now, code: "", items: [], message: "Edit the widget and enter your list code.")
        }
        do {
            let code = try FirebaseList.normalizedCode(value)
            let items = try await FirebaseList.fetchItems(code)
            return ListEntry(date: .now, code: code, items: items, message: nil)
        } catch {
            return ListEntry(date: .now, code: value, items: [], message: "Couldn’t load list. Check your connection and code.")
        }
    }
}

struct OurListWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ListEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Our List").font(.headline)
                Spacer()
                if entry.message == nil {
                    Text("\(remaining.count) left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let message = entry.message {
                Text(message).font(.subheadline).foregroundStyle(.secondary)
            } else if remaining.isEmpty {
                Text("All done for now!").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(remaining.prefix(family == .systemLarge ? 8 : 4)) { item in
                    Button(intent: ToggleItemIntent(listCode: entry.code, itemID: item.id, completed: true)) {
                        HStack(spacing: 9) {
                            Image(systemName: "circle")
                            Text(item.title).lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Complete \(item.title)")
                }
            }
            Spacer(minLength: 0)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var remaining: [TodoItem] { entry.items.filter { !$0.completed } }
}

struct OurListWidget: Widget {
    let kind = "OurListWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WidgetSetupIntent.self, provider: ListProvider()) { entry in
            OurListWidgetView(entry: entry)
        }
        .configurationDisplayName("Our List")
        .description("Check off shared tasks from your Home Screen.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

@main
struct OurListWidgetBundle: WidgetBundle {
    var body: some Widget { OurListWidget() }
}
