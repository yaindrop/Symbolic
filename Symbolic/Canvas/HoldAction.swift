import Foundation
import SwiftUI

struct HoldActionPopover: View {
    let position: Point2?

    var body: some View {
        if let position {
            HStack {
                Color.clear
                    .popover(isPresented: .constant(true)) {
                        VStack {
                            ControlGroup {
                                Button("Arc", systemImage: "circle") { }
                                Button("Bezier", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath") { }
                                Button("Line", systemImage: "chart.xyaxis.line") { }
                            } label: {
                                Text("Type")
                            }.controlGroupStyle(.navigation)
                        }
                        .padding()
                    }
            }
            .border(.red)
            .frame(width: 1, height: 1)
            .position(position)
        }
    }
}
