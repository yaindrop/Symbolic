import Combine
import SwiftUI

let appEvent = CurrentValueSubject<UIEvent?, Never>(nil)

@main
struct SymbolicApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
                    UIWindow.modify()
                }
        }
    }
}

extension UIWindow {
    @objc(sendEventModified:) func sendEventModified(_ event: UIEvent) {
        appEvent.send(event)
        sendEventModified(event)
        appEvent.send(nil)
    }

    @objc fileprivate static func modify(_: Bool = true) {
        guard let originalMethod = class_getInstanceMethod(UIWindow.self, #selector(sendEvent(_:))),
              let modifiedMethod = class_getInstanceMethod(UIWindow.self, #selector(sendEventModified(_:))) else { return }
        method_exchangeImplementations(originalMethod, modifiedMethod)
    }
}
