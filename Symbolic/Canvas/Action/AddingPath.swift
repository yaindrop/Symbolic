import Combine
import Foundation
import SwiftUI

class AddingPathModel: Store {
    @Trackable var from: Point2? = nil
    @Trackable var to: Point2 = .zero

    var active: Bool { from != nil }
    var segment: PathSegment? {
        guard let from else { return nil }
        return .init(from: from, to: to, edge: .line(.init()))
    }

    func onStart(from: Point2) {
        update {
            $0(\._from, from)
            $0(\._to, from)
        }
    }

    func onEnd() {
        update {
            $0(\._from, nil)
            $0(\._to, .zero)
        }
    }

    func subscribe(to multipleTouch: MultipleTouchModel) {
        multipleTouch.$panInfo
            .sink { self.onPan($0) }
            .store(in: &subscriptions)
    }

    private func onPan(_ info: PanInfo?) {
        guard active, let info else { return }
        update { $0(\._to, info.current) }
    }

    private var subscriptions = Set<AnyCancellable>()
}

struct AddingPath: View {
    @Selected var addingPathSegment = store.addingPath.segment

    var body: some View {
        if let addingPathSegment {
            SUPath { addingPathSegment.append(to: &$0) }
                .stroke(.blue, style: .init(lineWidth: 4))
//            HStack {
//                Color.clear
//                    .popover(isPresented: .constant(true)) {
//                        VStack {
//                            ControlGroup {
//                                Button("Arc", systemImage: "circle") { }
//                                Button("Bezier", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath") { }
//                                Button("Line", systemImage: "chart.xyaxis.line") { }
//                            } label: {
//                                Text("Type")
//                            }.controlGroupStyle(.navigation)
//                        }
//                        .padding()
//                    }
//            }
//            .border(.red)
//            .frame(width: 1, height: 1)
//            .position(position)
        }
    }
}
