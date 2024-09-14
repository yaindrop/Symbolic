import SwiftUI

// MARK: - DndList

struct DndListHovering: Equatable, Hashable {
    var id: UUID
    var isAfter: Bool
}

class DndListModel: ObservableObject {
    @Published var hovering: DndListHovering?
}

struct DndListTransferable: Codable, Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: DndListTransferable.self, contentType: .item)
    }
}

// MARK: - DndListHoveringIndicator

struct DndListHoveringIndicator: View {
    @EnvironmentObject var model: DndListModel
    var members: [UUID]
    var index: Int

    var body: some View {
        content
    }

    @ViewBuilder var content: some View {
        let showBeforeIndicator = showBeforeIndicator,
            showAfterIndicator = showAfterIndicator
        if showBeforeIndicator || showAfterIndicator {
            VStack(spacing: 0) {
                rect.opacity(showBeforeIndicator ? 1 : 0)
                Spacer()
                rect.opacity(showAfterIndicator ? 1 : 0)
            }
        }
    }

    var showBeforeIndicator: Bool {
        guard index == 0 else { return false }
        let id = members[index]
        return model.hovering == .init(id: id, isAfter: false)
    }

    var showAfterIndicator: Bool {
        guard let hovering = model.hovering else { return false }
        let id = members[index]
        return hovering == .init(id: id, isAfter: true) || members.indices.contains(index + 1) && hovering == .init(id: members[index + 1], isAfter: false)
    }

    @ViewBuilder var rect: some View {
        Rectangle()
            .fill(.blue)
            .frame(maxWidth: .infinity, maxHeight: 2)
            .padding(.leading, 12)
            .allowsHitTesting(false)
    }
}

// MARK: - DndListDropDelegate

struct DndListDropDelegate: DropDelegate {
    @ObservedObject var model: DndListModel
    var id: UUID
    var size: CGSize = .zero
    var onDrop: (UUID, _ isAfter: Bool) -> Void

    func dropEntered(info: DropInfo) {
        model.hovering = .init(id: id, isAfter: isAfter(info: info))
    }

    func dropExited(info _: DropInfo) {
        model.hovering = nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        model.hovering = .init(id: id, isAfter: isAfter(info: info))
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        model.hovering = nil
        let isAfter = isAfter(info: info)
        loadTransferable(info: info) {
            onDrop($0.id, isAfter)
        }
        return true
    }

    private func isAfter(info: DropInfo) -> Bool {
        info.location.y > size.height / 2
    }

    private func loadTransferable(info: DropInfo, _ callback: @escaping (DndListTransferable) -> Void) {
        let providers = info.itemProviders(for: [.item])
        guard let provider = providers.first else { return }
        _ = provider.loadTransferable(type: DndListTransferable.self) { result in
            guard let transferable = try? result.get() else { return }
            Task { @MainActor in callback(transferable) }
        }
    }
}
