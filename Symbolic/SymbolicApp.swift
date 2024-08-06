import SwiftUI

@main
struct SymbolicApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear(perform: UIApplication.shared.addTapGestureRecognizer)
        }
    }
}

extension UIApplication {
    func addTapGestureRecognizer() {
        guard let windowScene = Self.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        let tapGesture = UIPanGestureRecognizer(target: self, action: #selector(panAction))
        tapGesture.requiresExclusiveTouchType = false
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        window.addGestureRecognizer(tapGesture)
    }
}

extension UIApplication: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool {
        true
    }

    @objc func panAction(_ recognizer: UIPanGestureRecognizer) {
        global.root.update(rootPanLocation: recognizer.location(in: nil))
        if recognizer.state == .ended {
            global.root.update(rootPanLocation: nil)
        }
    }
}
