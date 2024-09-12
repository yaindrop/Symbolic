import SwiftUI

extension ContextMenuView {
    struct ZoomButton: View {
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: "arrow.up.left.and.arrow.down.right.square")
            }
            .frame(minWidth: 32)
            .tint(.label)
        }
    }

    struct RenameButton: View {
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: "character.cursor.ibeam")
            }
            .frame(minWidth: 32)
            .tint(.label)
        }
    }

    struct LockButton: View {
        let locked: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: locked ? "lock.open" : "lock")
                    .foregroundStyle(locked ? .blue : .label)
            }
            .frame(minWidth: 32)
            .tint(.label)
        }
    }

    struct GroupButton: View {
        let grouped: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: grouped ? "rectangle.3.group" : "square.on.square.squareshape.controlhandles")
            }
            .frame(minWidth: 32)
            .tint(.label)
        }
    }

    struct SelectButton: View {
        let selecting: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: "checklist")
                    .foregroundStyle(selecting ? .blue : .label)
            }
            .frame(minWidth: 32)
            .tint(.label)
        }
    }

    struct CopyMenu: View {
        let copyAction: () -> Void
        let cutAction: () -> Void
        let duplicateAction: () -> Void

        var body: some View {
            Menu {
                Button("Copy", systemImage: "doc.on.doc") { copyAction() }
                Button("Cut", systemImage: "scissors") { cutAction() }
                Button("Duplicate", systemImage: "plus.square.on.square") { duplicateAction() }
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .menuOrder(.fixed)
            .frame(minWidth: 32)
            .tint(.label)
        }
    }

    struct DeleteButton: View {
        let action: () -> Void

        var body: some View {
            Button(role: .destructive, action: action) {
                Image(systemName: "trash")
            }
            .frame(minWidth: 32)
        }
    }
}
