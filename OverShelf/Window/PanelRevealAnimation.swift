import CoreGraphics

struct PanelRevealState {
    private(set) var progress: CGFloat = 0
    private(set) var target: CGFloat = 0
    private(set) var isOrderedIn = false
    private(set) var acceptsMouseEvents = false

    mutating func startOpening() {
        target = 1
        isOrderedIn = true
        acceptsMouseEvents = false
    }

    mutating func startClosing() {
        target = 0
        acceptsMouseEvents = false
    }

    mutating func update(progress: CGFloat) {
        self.progress = min(1, max(0, progress))
        if target == 1, self.progress == 1 {
            isOrderedIn = true
            acceptsMouseEvents = true
        } else if target == 0, self.progress == 0 {
            isOrderedIn = false
            acceptsMouseEvents = false
        }
    }
}

struct PanelRevealAnimation {
    static let openingDuration: CGFloat = 0.24
    static let closingDuration: CGFloat = 0.18
    static let reducedMotionDuration: CGFloat = 0.10

    let from: CGFloat
    let to: CGFloat
    let duration: CGFloat
    let usesReveal: Bool

    init(from: CGFloat, to: CGFloat, reduceMotion: Bool) {
        self.from = min(1, max(0, from))
        self.to = min(1, max(0, to))
        self.usesReveal = !reduceMotion

        let fullDuration = reduceMotion
            ? Self.reducedMotionDuration
            : (to >= from ? Self.openingDuration : Self.closingDuration)
        self.duration = fullDuration * abs(self.to - self.from)
    }

    func progress(elapsed: CGFloat) -> CGFloat {
        guard duration > 0 else { return to }
        let fraction = min(1, max(0, elapsed / duration))
        let eased: CGFloat
        if to >= from {
            eased = 1 - pow(1 - fraction, 3)
        } else {
            eased = pow(fraction, 3)
        }
        return from + (to - from) * eased
    }
}
