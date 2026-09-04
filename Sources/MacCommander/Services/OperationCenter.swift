import Combine
import Foundation

enum FileOperationKind: String, Sendable {
    case copy = "Copy"
    case move = "Move"
    case trash = "Trash"
}
struct FileOperationStatus: Identifiable, Sendable {
    let id: UUID
    let kind: FileOperationKind
    let total: Int
    var completed: Int
    var currentName: String
    var failure: String?
    var isFinished: Bool
}

@MainActor
final class OperationCenter: ObservableObject {
    @Published private(set) var operations: [FileOperationStatus] = []

    var activeOperations: [FileOperationStatus] { operations.filter { !$0.isFinished } }
    var recentFailure: String? { operations.last(where: { $0.failure != nil })?.failure }

    func perform(_ kind: FileOperationKind, sources: [URL], destination: URL? = nil, completion: @escaping @MainActor () -> Void) {
        guard !sources.isEmpty else { return }
        let id = UUID()
        operations.append(FileOperationStatus(id: id, kind: kind, total: sources.count, completed: 0, currentName: sources[0].lastPathComponent, isFinished: false))

        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> String? in
                let fm = FileManager.default
                do {
                    for (index, source) in sources.enumerated() {
                        try Task.checkCancellation()
                        await MainActor.run { [weak self] in self?.update(id: id, completed: index, name: source.lastPathComponent) }
                        switch kind {
                        case .copy:
                            guard let destination else { continue }
                            try fm.copyItem(at: source, to: FileSystemService.uniqueDestination(for: source, in: destination))
                        case .move:
                            guard let destination else { continue }
                            try fm.moveItem(at: source, to: FileSystemService.uniqueDestination(for: source, in: destination))
                        case .trash:
                            _ = try fm.trashItem(at: source, resultingItemURL: nil)
                        }
                    }
                    return nil
                } catch {
                    return error.localizedDescription
                }
            }.value
            finish(id: id, failure: result)
            completion()
        }
    }

    private func update(id: UUID, completed: Int, name: String) {
        guard let index = operations.firstIndex(where: { $0.id == id }) else { return }
        operations[index].completed = completed
        operations[index].currentName = name
    }

    private func finish(id: UUID, failure: String?) {
        guard let index = operations.firstIndex(where: { $0.id == id }) else { return }
        operations[index].completed = failure == nil ? operations[index].total : operations[index].completed
        operations[index].failure = failure
        operations[index].isFinished = true
        if operations.count > 20 { operations.removeFirst(operations.count - 20) }
    }
}
