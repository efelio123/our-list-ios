import SwiftUI
import FirebaseFirestore
import WidgetKit

@MainActor
final class ListViewModel: ObservableObject {
    @Published var items: [TodoItem] = []
    @Published var errorMessage: String?
    @Published var isBusy = true
    private var listener: ListenerRegistration?
    private(set) var code: String?

    func connect() async {
        listener?.remove()
        listener = nil
        items = []
        isBusy = true
        defer { isBusy = false }
        do {
            let normalized = try FirebaseList.bundledCode()
            try await FirebaseList.verifyList(normalized)
            code = normalized
            errorMessage = nil
            listener = FirebaseList.itemsQuery(normalized).addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    if let error {
                        self?.errorMessage = error.localizedDescription
                    } else if let snapshot {
                        self?.items = snapshot.documents.compactMap(TodoItem.init(document:))
                        WidgetCenter.shared.reloadTimelines(ofKind: "OurListWidget")
                    }
                }
            }
        } catch {
            code = nil
            errorMessage = error.localizedDescription
        }
    }

    func add(_ title: String) async {
        guard let code else { return }
        do { try await FirebaseList.add(title, to: code) }
        catch { errorMessage = error.localizedDescription }
    }

    func toggle(_ item: TodoItem) async {
        guard let code else { return }
        do { try await FirebaseList.setCompleted(!item.completed, itemID: item.id, code: code) }
        catch { errorMessage = error.localizedDescription }
    }

    func delete(_ item: TodoItem) async {
        guard let code else { return }
        do { try await FirebaseList.delete(itemID: item.id, code: code) }
        catch { errorMessage = error.localizedDescription }
    }

}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = ListViewModel()
    @State private var newItem = ""
    @State private var widgetIsInstalled: Bool?
    @FocusState private var taskFieldIsFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if model.code == nil { setupView }
                else { listView }
            }
            .navigationTitle("Our List")
            .alert("Couldn’t update list", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "Please try again.")
            }
            .task {
                guard model.code == nil else { return }
                await model.connect()
            }
            .task { await refreshWidgetStatus() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshWidgetStatus() } }
            }
        }
    }

    private var setupView: some View {
        VStack(spacing: 16) {
            if model.isBusy {
                ProgressView("Connecting to Our List…")
            } else {
                Text("Couldn’t connect to Our List")
                    .font(.headline)
                Button("Try again") { Task { await model.connect() } }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var listView: some View {
        List {
            Section {
                HStack {
                    TextField("Add a task", text: $newItem)
                        .submitLabel(.done)
                        .focused($taskFieldIsFocused)
                        .onSubmit { addItem() }
                    Button(action: addItem) { Image(systemName: "plus.circle.fill") }
                        .disabled(newItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel("Add task")
                }
            }
            Section("To do") {
                ForEach(model.items.filter { !$0.completed }) { item in row(item) }
            }
            Section("Done") {
                ForEach(model.items.filter(\.completed)) { item in row(item) }
            }
            if widgetIsInstalled == false {
                Section {
                    Text(widgetMessage)
                } header: { Text("Home Screen widget") }
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .onTapGesture { taskFieldIsFocused = false }
    }

    private var widgetMessage: String {
        "Add Our List to your Home Screen to see and check off tasks. Touch and hold an empty area, open the widget picker, and search for Our List."
    }

    private func refreshWidgetStatus() async {
        guard #available(iOS 18.0, *) else {
            // WidgetCenter.currentConfigurations() is only available on iOS 18.
            // Keep the general widget setup guidance on earlier deployment targets.
            widgetIsInstalled = nil
            return
        }

        do {
            let widgets = try await WidgetCenter.shared.currentConfigurations()
            widgetIsInstalled = widgets.contains { $0.kind == "OurListWidget" }
        } catch {
            widgetIsInstalled = nil
        }
    }

    private func row(_ item: TodoItem) -> some View {
        HStack(spacing: 12) {
            Button {
                taskFieldIsFocused = false
                Task { await model.toggle(item) }
            } label: {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.completed ? "Mark incomplete" : "Complete task")
            Text(item.title)
                .strikethrough(item.completed)
                .foregroundStyle(item.completed ? .secondary : .primary)
                .onTapGesture { taskFieldIsFocused = false }
            Spacer()
            Button(role: .destructive) {
                taskFieldIsFocused = false
                Task { await model.delete(item) }
            } label: { Image(systemName: "trash") }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete task")
        }
    }

    private func addItem() {
        let title = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        newItem = ""
        taskFieldIsFocused = false
        Task { await model.add(title) }
    }
}
