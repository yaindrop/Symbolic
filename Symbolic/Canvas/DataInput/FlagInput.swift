import Foundation
import SwiftUI

// MARK: - FlagInput

struct FlagInput: View {
    var body: some View {
        HStack {
            Button {
                onChange(!flag)
            } label: {
                Text(flag ? "True" : "False").font(.footnote)
            }
            .tint(.label)
        }
        .frame(height: 20)
        .padding(6)
        .background(Color.tertiarySystemBackground)
        .cornerRadius(6)
    }

    init(flag: Bool,
         onChange: @escaping (Bool) -> Void = { _ in }) {
        self.flag = flag
        self.onChange = onChange
    }

    private let flag: Bool
    private let onChange: (Bool) -> Void
}
