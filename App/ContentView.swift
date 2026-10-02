import SwiftUI
import FirebaseFirestore
import WidgetKit

@MainActor
final class ListViewModel: ObservableObject {
    @Published var items: [TodoItem] = []
    @Published var errorMessage: String?
    @Published var isBusy = false
    private var listener: ListenerRegistration?
    private(set) var code: String?

    func connect(_ value: String) async {
        listener?.remove()
        listener = nil
        items = []
        isBusy = true
        defer { isBusy = false }
        do {
            let normalized = try FirebaseList.normalizedCode(value)
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

    func disconnect() {
        listener?.remove()
        listener = nil
        code = nil
        items = []
    }
}

struct ContentView: View {
    @AppStorage("listCode") private var savedCode = ""
    @StateObject private var model = ListViewModel()
    @State private var enteredCode = ""
    @State private var newItem = ""

    var body: some View {
        NavigationStack {
            Group {
                if model.code == nil { setupView }
                else { listView }
            }
            .navigationTitle("Our List")
            .toolbar {
                if model.code != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            ShareLink(item: savedCode) { Label("Share list code", systemImage: "square.and.arrow.up") }
                            Button("Change list", systemImage: "arrow.left.arrow.right") {
                                savedCode = ""
                                enteredCode = ""
                                model.disconnect()
                            }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                }
            }
            .alert("Couldn’t update list", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "Please try again.")
            }
            .task {
                guard !savedCode.isEmpty, model.code == nil else { return }
                await model.connect(savedCode)
            }
        }
    }

    private var setupView: some View {
        Form {
            Section("Connect to our list") {
                TextField("32-character list code", text: $enteredCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                Button("Connect") {
                    Task {
                        await model.connect(enteredCode)
                        if let code = model.code { savedCode = code }
                    }
                }
                .disabled(model.isBusy || enteredCode.isEmpty)
            } footer: {
                Text("Use the same private list code on both phones. You will receive it after Firebase setup.")
            }
            if model.isBusy { ProgressView() }
        }
    }

    private var listView: some View {
        List {
            Section {
                HStack {
                    TextField("Add a task", text: $newItem)
                        .submitLabel(.done)
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
            Section {
                Text("Widget setup: add the Our List widget to your Home Screen, long press it, choose Edit Widget, and enter this list code.")
                Text(savedCode)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            } header: { Text("List code") }
        }
    }

    private func row(_ item: TodoItem) -> some View {
        HStack(spacing: 12) {
            Button {
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
            Spacer()
            Button(role: .destructive) {
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
        Task { await model.add(title) }
    }
}
