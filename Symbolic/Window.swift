import Foundation
import SwiftUI

// MARK: - WindowIdKey

private struct WindowIdKey: EnvironmentKey {
    typealias Value = UUID
    static let defaultValue = UUID()
}

extension EnvironmentValues {
    var windowId: UUID {
        get { self[WindowIdKey.self] }
        set { self[WindowIdKey.self] = newValue }
    }
}

// MARK: - WindowData

struct WindowData {
    let id: UUID = UUID()
    let view: AnyView
    var origin: Point2 = .zero
    var size: CGSize = .zero
    var zIndex: Double

    var rect: CGRect { CGRect(origin: origin, size: size) }
}

// MARK: - WindowModel

class WindowModel: ObservableObject {
    @Published var idToWindow: [UUID: WindowData] = [:]
    @Published var windowIds: [UUID] = []
    @Published var rootSize: CGSize = .zero

    var windows: [WindowData] { windowIds.compactMap { idToWindow[$0] } }
}

extension WindowModel {
    func register(@ViewBuilder _ getWindow: @escaping () -> any View) {
        let windowData = WindowData(view: AnyView(getWindow()), zIndex: Double(idToWindow.count))
        idToWindow[windowData.id] = windowData
        windowIds.append(windowData.id)
    }

    func deregister(windowId: UUID) {
        idToWindow.removeValue(forKey: windowId)
        windowIds.removeAll { $0 == windowId }
    }

    private func sort() {
        windowIds.sort {
            guard let data0 = idToWindow[$0] else { return true }
            guard let data1 = idToWindow[$1] else { return false }
            return data0.zIndex < data1.zIndex
        }
    }
}

extension WindowModel {
    func onMoving(windowId: UUID, origin: Point2) {
        guard var window = idToWindow[windowId] else { return }
        window.origin = origin
        idToWindow[windowId] = window
    }

    func onMoved(windowId: UUID, origin: Point2, inertia: Vector2) {
        guard var window = idToWindow[windowId] else { return }
        window.origin = origin
        idToWindow[windowId] = window
        withAnimation {
            if inertia.length > 240 {
                idToWindow[windowId]?.origin = origin + inertia / 2
            }
            clampOrigin(windowId: windowId)
        }
    }

    func clampOrigin(windowId: UUID) {
        guard var window = idToWindow[windowId] else { return }
        window.origin = window.rect.clamped(by: CGRect(rootSize)).origin
        idToWindow[windowId] = window
    }
}

// MARK: - WindowRoot

struct WindowRoot: View {
    @EnvironmentObject var model: WindowModel

    var body: some View {
        ZStack {
            ForEach(model.windows, id: \.id) { window in
                window.view
                    .readSize { model.idToWindow[window.id]?.size = $0 }
                    .offset(x: window.origin.x, y: window.origin.y)
                    .zIndex(window.zIndex)
                    .environment(\.windowId, window.id)
                    .atCornerPosition(.topLeading)
                    .onChange(of: window.size) {
                        withAnimation {
                            model.clampOrigin(windowId: window.id)
                        }
                    }
            }
        }
        .readSize { model.rootSize = $0 }
        .onChange(of: model.rootSize) {
            withAnimation {
                for id in model.windowIds {
                    model.clampOrigin(windowId: id)
                }
            }
        }
    }
}
