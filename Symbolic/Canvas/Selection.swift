import Combine
import Foundation
import SwiftUI

class PendingSelection: ObservableObject {
    @Published private(set) var from: Point2? = nil
    @Published private(set) var to: Point2 = .zero

    var active: Bool { from != nil }
    var rect: CGRect? {
        guard let from else { return nil }
        return .init(from: from, to: to)
    }

    func onStart(from: Point2) {
        self.from = from
        to = from
    }

    func onEnd() {
        from = nil
        to = .zero
    }

    init(touchContext: MultipleTouchContext) {
        touchContext.$panInfo
            .sink { value in
                guard self.active, let info = value else { return }
                self.onPanInfo(info)
            }
            .store(in: &subscriptions)
    }

    // MARK: private

    private var subscriptions = Set<AnyCancellable>()

    private func onPanInfo(_ pan: PanInfo) {
        to = pan.current
    }
}

struct PendingSelectionView: View {
    @EnvironmentObject var pendingSelection: PendingSelection

    var body: some View {
        if let rect = pendingSelection.rect {
            RoundedRectangle(cornerRadius: 8)
                .fill(.gray.opacity(0.2))
                .stroke(.gray.opacity(0.5))
                .frame(width: rect.width, height: rect.height)
                .position(rect.center)
        }
    }
}
