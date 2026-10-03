import SwiftUI
import WidgetKit

struct ListEntry: TimelineEntry {
    let date: Date
    let code: String
    let items: [TodoItem]
    let message: String?
}

struct ListProvider: TimelineProvider {
    func placeholder(in context: Context) -> ListEntry {
        ListEntry(date: .now, code: "", items: [], message: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ListEntry) -> Void) {
        Task { completion(await load()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ListEntry>) -> Void) {
        Task {
            let entry = await load()
            completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
        }
    }

    private func load() async -> ListEntry {
        do {
            let code = try FirebaseList.bundledCode()
            let items = try await FirebaseList.fetchItems(code)
            return ListEntry(date: .now, code: code, items: items, message: nil)
        } catch {
            return ListEntry(date: .now, code: "", items: [], message: "Couldn’t load list. Check your connection.")
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
        StaticConfiguration(kind: kind, provider: ListProvider()) { entry in
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
