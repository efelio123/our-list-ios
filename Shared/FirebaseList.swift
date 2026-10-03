import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

struct TodoItem: Identifiable, Equatable {
    let id: String
    let title: String
    let completed: Bool
    let createdAt: Date

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard let title = data["title"] as? String,
              let completed = data["completed"] as? Bool,
              let createdAt = data["createdAt"] as? Timestamp else { return nil }
        id = document.documentID
        self.title = title
        self.completed = completed
        self.createdAt = createdAt.dateValue()
    }
}

enum ListError: LocalizedError {
    case invalidCode
    case missingList
    case missingFirebaseConfiguration
    case missingListCode

    var errorDescription: String? {
        switch self {
        case .invalidCode: "Enter a 32-character list code."
        case .missingList: "That list was not found. Check the code and try again."
        case .missingFirebaseConfiguration: "Add GoogleService-Info.plist to both targets."
        case .missingListCode: "This build is missing its private list configuration."
        }
    }
}

enum FirebaseList {
    static func configure() throws {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            throw ListError.missingFirebaseConfiguration
        }
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
    }

    static func normalizedCode(_ value: String) throws -> String {
        let code = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard code.range(of: "^[0-9a-f]{32}$", options: .regularExpression) != nil else {
            throw ListError.invalidCode
        }
        return code
    }

    static func bundledCode() throws -> String {
        guard let url = Bundle.main.url(forResource: "list-code", withExtension: "txt") else {
            throw ListError.missingListCode
        }
        return try normalizedCode(String(contentsOf: url, encoding: .utf8))
    }

    static func signIn() async throws {
        try configure()
        if Auth.auth().currentUser != nil { return }
        _ = try await Auth.auth().signInAnonymously()
    }

    static func listReference(_ code: String) -> DocumentReference {
        Firestore.firestore().collection("lists").document(code)
    }

    static func verifyList(_ code: String) async throws {
        try await signIn()
        let snapshot = try await listReference(code).getDocument()
        guard snapshot.exists else { throw ListError.missingList }
    }

    static func itemsQuery(_ code: String) -> Query {
        listReference(code).collection("items").order(by: "createdAt")
    }

    static func fetchItems(_ code: String) async throws -> [TodoItem] {
        try await signIn()
        return try await itemsQuery(code).getDocuments().documents.compactMap(TodoItem.init(document:))
    }

    static func add(_ title: String, to code: String) async throws {
        try await signIn()
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned.count <= 160 else { return }
        let item = listReference(code).collection("items").document()
        try await item.setData([
            "title": cleaned,
            "completed": false,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    static func setCompleted(_ value: Bool, itemID: String, code: String) async throws {
        try await signIn()
        try await listReference(code).collection("items").document(itemID).updateData([
            "completed": value,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    static func delete(itemID: String, code: String) async throws {
        try await signIn()
        try await listReference(code).collection("items").document(itemID).delete()
    }
}
