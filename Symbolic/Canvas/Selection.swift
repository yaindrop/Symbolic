import Combine
import Foundation
import SwiftUI

class PendingSelectionModel: ObservableObject {
    @Published fileprivate(set) var from: Point2? = nil
    @Published fileprivate(set) var to: Point2 = .zero

    var active: Bool { from != nil }
    var rect: CGRect? {
        guard let from else { return nil }
        return .init(from: from, to: to)
    }

    fileprivate var subscriptions = Set<AnyCancellable>()
}

struct SelectionUpdater {
    let pendingSelectionModel: PendingSelectionModel

    var from: Point2? { pendingSelectionModel.from }
    var to: Point2 { pendingSelectionModel.to }

    func onStart(from: Point2) {
        pendingSelectionModel.from = from
        pendingSelectionModel.to = from
    }

    func onEnd() {
        pendingSelectionModel.from = nil
        pendingSelectionModel.to = .zero
    }

    func subscribe(to multipleTouch: MultipleTouchModel) {
        multipleTouch.panInfoSubject
            .sink { value in
                guard self.pendingSelectionModel.active, let info = value else { return }
                self.pendingSelectionModel.to = info.current
            }
            .store(in: &pendingSelectionModel.subscriptions)
    }
}

struct PendingSelectionView: View {
    @EnvironmentObject var pendingSelectionModel: PendingSelectionModel

    var body: some View {
        if let rect = pendingSelectionModel.rect {
            RoundedRectangle(cornerRadius: 8)
                .fill(.gray.opacity(0.2))
                .stroke(.gray.opacity(0.5))
                .frame(width: rect.width, height: rect.height)
                .position(rect.center)
        }
    }
}
