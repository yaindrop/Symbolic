import UIKit

// MARK: - TouchDebugView

class TouchDebugView: UIView {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        for touch in touches {
            createTouchSpotView(for: touch)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        for touch in touches {
            removeTouchSpotView(for: touch)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        for touch in touches {
            removeTouchSpotView(for: touch)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        for touch in touches {
            updateTouchSpotView(for: touch)
        }
    }

    // MARK: private

    private class TouchSpotView: UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = UIColor.lightGray
            alpha = 0.5
        }

        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }

        override var bounds: CGRect {
            get { super.bounds }
            set(newBounds) {
                super.bounds = newBounds
                layer.cornerRadius = newBounds.size.width / 2.0
            }
        }
    }

    private var touchSpotViews = [UITouch: TouchSpotView]()

    private func createTouchSpotView(for touch: UITouch) {
        let touchSpotView = TouchSpotView()
        touchSpotView.bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
        touchSpotView.center = touch.location(in: self)

        addSubview(touchSpotView)
        UIView.animate(withDuration: 0.1) { touchSpotView.bounds.size = CGSize(80, 80) }

        touchSpotViews[touch] = touchSpotView
    }

    private func updateTouchSpotView(for touch: UITouch) {
        guard let touchSpotView = touchSpotViews[touch] else { return }
        touchSpotView.center = touch.location(in: self)
    }

    private func removeTouchSpotView(for touch: UITouch) {
        if let view = touchSpotViews.removeValue(forKey: touch) {
            view.removeFromSuperview()
        }
    }
}
