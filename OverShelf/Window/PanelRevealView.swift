import Cocoa

final class PanelRevealViewController: NSViewController {
    let revealView: PanelRevealView
    private let hostedController: NSViewController

    init(hostedController: NSViewController) {
        self.hostedController = hostedController
        self.revealView = PanelRevealView(hostedView: hostedController.view)
        super.init(nibName: nil, bundle: nil)
        addChild(hostedController)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = revealView
    }
}

final class PanelRevealView: NSView {
    private final class ClipView: NSView {
        override var isFlipped: Bool { true }
    }

    override var isFlipped: Bool { true }

    private let clipView = ClipView()
    private let hostedView: NSView

    var progress: CGFloat = 0 {
        didSet {
            needsLayout = true
            layoutSubtreeIfNeeded()
        }
    }

    var usesReveal = true {
        didSet { needsLayout = true }
    }

    init(hostedView: NSView) {
        self.hostedView = hostedView
        super.init(frame: .zero)
        wantsLayer = true
        clipView.wantsLayer = true
        clipView.layer?.masksToBounds = true
        addSubview(clipView)
        clipView.addSubview(hostedView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let clampedProgress = min(1, max(0, progress))
        let visibleHeight = usesReveal ? bounds.height * clampedProgress : bounds.height
        clipView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: visibleHeight)
        hostedView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        clipView.alphaValue = usesReveal ? min(1, 0.85 + clampedProgress * 0.15) : clampedProgress
    }
}
