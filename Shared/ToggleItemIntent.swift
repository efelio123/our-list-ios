import AppIntents
import WidgetKit

struct ToggleItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Check off task"
    static var description = IntentDescription("Update a task in the shared list.")

    @Parameter(title: "List code") var listCode: String
    @Parameter(title: "Task ID") var itemID: String
    @Parameter(title: "Completed") var completed: Bool

    init() {}

    init(listCode: String, itemID: String, completed: Bool) {
        self.listCode = listCode
        self.itemID = itemID
        self.completed = completed
    }

    func perform() async throws -> some IntentResult {
        let code = try FirebaseList.normalizedCode(listCode)
        try await FirebaseList.setCompleted(completed, itemID: itemID, code: code)
        WidgetCenter.shared.reloadTimelines(ofKind: "OurListWidget")
        return .result()
    }
}
