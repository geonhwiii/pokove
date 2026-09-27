import Foundation
import Observation

nonisolated struct TodoItem: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var isDone: Bool
    let createdAt: Date
    var completedAt: Date?
}

/// A small local to-do list, kept in the order the page shows it: open items first (newest on
/// top), then finished ones.
@Observable
final class TodoStore {
    private(set) var items: [TodoItem] = []

    @ObservationIgnored private let storeURL: URL

    init(storeURL: URL = TodoStore.defaultStoreURL) {
        self.storeURL = storeURL
        load()
    }

    static var defaultStoreURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #if DEBUG
        let name = "todos-debug.json"
        #else
        let name = "todos.json"
        #endif
        return support.appendingPathComponent("pokove", isDirectory: true).appendingPathComponent(name)
    }

    var remainingCount: Int { items.filter { !$0.isDone }.count }
    var doneCount: Int { items.count - remainingCount }

    // MARK: Editing

    func add(_ title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        items.insert(TodoItem(id: UUID(), title: title, isDone: false, createdAt: Date(), completedAt: nil), at: 0)
        save()
    }

    func toggle(_ id: TodoItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isDone.toggle()
        items[index].completedAt = items[index].isDone ? Date() : nil
        save()
    }

    func rename(_ id: TodoItem.ID, to title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if title.isEmpty {
            items.remove(at: index)
        } else {
            items[index].title = title
        }
        save()
    }

    func delete(_ id: TodoItem.ID) {
        items.removeAll { $0.id == id }
        save()
    }

    func clearCompleted() {
        items.removeAll { $0.isDone }
        save()
    }

    /// Moves finished items below open ones. Called a beat after a toggle, so the check reads first.
    func settleOrder() {
        let open = items.filter { !$0.isDone }
        let done = items.filter(\.isDone).sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        let settled = open + done
        guard settled.map(\.id) != items.map(\.id) else { return }
        items = settled
        save()
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: storeURL) else { return }
        do {
            items = try JSONDecoder.todos.decode([TodoItem].self, from: data)
        } catch {
            // Keep an unreadable file instead of overwriting it with an empty list.
            let backup = storeURL.deletingPathExtension().appendingPathExtension("unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: storeURL, to: backup)
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder.todos.encode(items).write(to: storeURL, options: .atomic)
        } catch {
            NSLog("pokove: couldn't save to-dos: \(error.localizedDescription)")
        }
    }
}

private extension JSONEncoder {
    static var todos: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        return encoder
    }
}

private extension JSONDecoder {
    static var todos: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
